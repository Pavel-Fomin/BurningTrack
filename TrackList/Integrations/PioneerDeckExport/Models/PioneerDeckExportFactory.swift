//
//  PioneerDeckExportFactory.swift
//  TrackList
//
//  Сборка domain-модели Pioneer Export из нейтральных source-моделей.
//

import Foundation

/// Нейтральная модель исходного трека без зависимости от UI и TrackListManager.
public struct PioneerDeckSourceTrack: Sendable {
    /// Стабильный UUID трека BurningTrack.
    public let sourceTrackId: UUID

    /// Название из метаданных BurningTrack.
    public let title: String?

    /// Исполнитель из метаданных BurningTrack.
    public let artist: String?

    /// Длительность в секундах из метаданных BurningTrack.
    public let duration: Double

    /// Sample rate аудиофайла, если caller уже получил его безопасным способом.
    public let sampleRate: UInt32?

    /// Размер аудиофайла в байтах, если caller уже получил его безопасным способом.
    public let fileSize: UInt32?

    /// Bit depth аудиофайла, если caller уже получил его безопасным способом.
    public let sampleDepth: UInt16?

    /// Bitrate аудиофайла, если caller уже получил его безопасным способом.
    public let bitrate: UInt32?

    /// BPM * 100, если tempo уже есть в domain-данных.
    public let tempoX100: UInt32?

    /// Имя исходного файла.
    public let fileName: String

    /// Фактический URL аудиофайла, если caller уже его разрешил.
    public let sourceFileURL: URL?

    /// Создаёт нейтральный трек для factory.
    public init(
        sourceTrackId: UUID,
        title: String?,
        artist: String?,
        duration: Double,
        sampleRate: UInt32? = nil,
        fileSize: UInt32? = nil,
        sampleDepth: UInt16? = nil,
        bitrate: UInt32? = nil,
        tempoX100: UInt32? = nil,
        fileName: String,
        sourceFileURL: URL? = nil
    ) {
        self.sourceTrackId = sourceTrackId
        self.title = title
        self.artist = artist
        self.duration = duration
        self.sampleRate = sampleRate
        self.fileSize = fileSize
        self.sampleDepth = sampleDepth
        self.bitrate = bitrate
        self.tempoX100 = tempoX100
        self.fileName = fileName
        self.sourceFileURL = sourceFileURL
    }
}

/// Нейтральная модель плейлиста без зависимости от UI и TrackListManager.
public struct PioneerDeckSourcePlaylist: Sendable {
    /// Стабильный UUID плейлиста BurningTrack.
    public let sourcePlaylistId: UUID

    /// Имя плейлиста BurningTrack.
    public let name: String

    /// Треки плейлиста в пользовательском порядке.
    public let tracks: [PioneerDeckSourceTrack]

    /// Создаёт нейтральный плейлист для factory.
    public init(sourcePlaylistId: UUID, name: String, tracks: [PioneerDeckSourceTrack]) {
        self.sourcePlaylistId = sourcePlaylistId
        self.name = name
        self.tracks = tracks
    }
}

/// Собирает экспорт из BurningTrack-данных, не читая чужие rekordbox-структуры.
public enum PioneerDeckExportFactory {
    /// Создаёт PioneerDeckExport из плейлистов-источников.
    public static func makeExport(
        from playlists: [PioneerDeckSourcePlaylist],
        audioLayoutStrategy: any PioneerAudioLayoutStrategy = PlaceholderAudioLayoutStrategy()
    ) throws -> PioneerDeckExport {
        let uniqueTracks = makeUniqueTracks(
            from: playlists,
            audioLayoutStrategy: audioLayoutStrategy
        )
        let trackIdBySourceId = Dictionary(uniqueKeysWithValues: uniqueTracks.map { ($0.sourceTrackId, $0.id) })

        let deckPlaylists = playlists.enumerated().map { index, playlist in
            let entries = playlist.tracks.enumerated().compactMap { entryIndex, track in
                trackIdBySourceId[track.sourceTrackId].map {
                    PioneerDeckPlaylistEntry(trackId: $0, position: UInt32(entryIndex + 1))
                }
            }

            return PioneerDeckPlaylist(
                id: UInt32(index + 1),
                sourcePlaylistId: playlist.sourcePlaylistId,
                name: playlist.name,
                entries: entries
            )
        }

        let export = PioneerDeckExport(playlists: deckPlaylists, tracks: uniqueTracks)
        try export.validate()
        return export
    }

    /// Назначает UInt32 id детерминированно по UUID, чтобы один sourceTrackId не дублировался.
    private static func makeUniqueTracks(
        from playlists: [PioneerDeckSourcePlaylist],
        audioLayoutStrategy: any PioneerAudioLayoutStrategy
    ) -> [PioneerDeckTrack] {
        let tracksBySourceId = playlists
            .flatMap(\.tracks)
            .reduce(into: [UUID: PioneerDeckSourceTrack]()) { partial, track in
                partial[track.sourceTrackId] = partial[track.sourceTrackId] ?? track
            }

        return tracksBySourceId
            .values
            .sorted { $0.sourceTrackId.uuidString < $1.sourceTrackId.uuidString }
            .enumerated()
            .map { index, sourceTrack in
                let title = sourceTrack.title?.nilIfBlank ?? URL(fileURLWithPath: sourceTrack.fileName).deletingPathExtension().lastPathComponent
                let artist = sourceTrack.artist?.nilIfBlank ?? ""
                let duration = sourceTrack.duration.isFinite ? max(0, sourceTrack.duration.rounded(.down)) : 0
                let usbPath = audioLayoutStrategy.audioUSBPath(
                    artist: artist,
                    album: nil,
                    fileName: sourceTrack.fileName
                )

                return PioneerDeckTrack(
                    id: UInt32(index + 1),
                    sourceTrackId: sourceTrack.sourceTrackId,
                    title: title,
                    artist: artist,
                    durationSeconds: UInt32(duration),
                    sampleRate: sourceTrack.sampleRate,
                    fileSize: sourceTrack.fileSize ?? fileSizeFromSourceURL(sourceTrack.sourceFileURL),
                    sampleDepth: sourceTrack.sampleDepth,
                    bitrate: sourceTrack.bitrate,
                    tempoX100: sourceTrack.tempoX100,
                    fileName: sourceTrack.fileName,
                    usbRelativePath: usbPath,
                    colorId: 0,
                    sourceFileURL: sourceTrack.sourceFileURL
                )
            }
    }

    /// Читает размер исходного файла только через файловую систему, без анализа аудиоформата.
    private static func fileSizeFromSourceURL(_ url: URL?) -> UInt32? {
        guard let url else { return nil }
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let size = attributes[.size] as? NSNumber
        else {
            return nil
        }

        // track_row хранит file_size как u4, поэтому слишком большой файл пока оставляем неизвестным.
        return UInt32(exactly: size.uint64Value)
    }
}

private extension String {
    /// Возвращает nil для пустых и пробельных строк.
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
