//
//  TrackRuntimeSnapshot.swift
//  TrackList
//
// Каноничное runtime-состояние трека.
// Это единый источник правды после чтения файла.

// Используется всеми экранами (плеер, треклист, фонотека, sheet)
// через единый контракт обновления.
// - не содержит UIImage (только Data)
// - не зависит от UI
// - не используется для сериализации
//
//  Created by PavelFomin on 23.04.2026.
//

import Foundation

struct TrackRuntimeSnapshot: Equatable {

    // MARK: - Идентичность

    let trackId: UUID

    // MARK: - Файл

    let fileName: String
    let isAvailable: Bool
    let technicalMetadata: TrackTechnicalMetadata

    // MARK: - Основное

    let title: String?
    let artist: String?
    let album: String?
    let albumArtist: String?
    let genre: String?
    let comment: String?

    // MARK: - Авторы

    let composer: String?
    let conductor: String?
    let lyricist: String?
    let remixer: String?

    // MARK: - Музыкальные атрибуты

    let grouping: String?
    let bpm: Int?
    let musicalKey: String?

    // MARK: - Нумерация

    let trackNumber: Int?
    let totalTracks: Int?
    let discNumber: Int?
    let totalDiscs: Int?

    // MARK: - Выпуск и идентификация

    let year: Int?
    let date: String?
    let publisherOrLabel: String?
    let copyright: String?
    let encodedBy: String?
    let isrc: String?

    // MARK: - Runtime-состояние

    let duration: Double?
    let artworkData: Data?
    let artworkSourceIdentifier: ArtworkSourceIdentifier?
    let updatedAt: Date

}

extension TrackRuntimeSnapshot {

    /// Сохраняет последние валидные runtime-значения, если повторное чтение файла временно не вернуло их.
    /// Явное изменение обложки или длительности всегда остаётся приоритетнее предыдущего snapshot.
    func preservingUnavailableRuntimeValues(
        from previousSnapshot: TrackRuntimeSnapshot?,
        changedFields: Set<TrackChangedField>
    ) -> TrackRuntimeSnapshot {
        guard let previousSnapshot else { return self }

        let duration = changedFields.contains(.duration)
            ? duration
            : duration ?? previousSnapshot.duration
        let artworkData = changedFields.contains(.artworkData)
            ? artworkData
            : artworkData ?? previousSnapshot.artworkData
        let artworkSourceIdentifier = changedFields.contains(.artworkData)
            ? artworkSourceIdentifier
            : artworkSourceIdentifier ?? previousSnapshot.artworkSourceIdentifier

        return TrackRuntimeSnapshot(
            trackId: trackId,
            fileName: fileName,
            isAvailable: isAvailable,
            technicalMetadata: technicalMetadata,
            title: title,
            artist: artist,
            album: album,
            albumArtist: albumArtist,
            genre: genre,
            comment: comment,
            composer: composer,
            conductor: conductor,
            lyricist: lyricist,
            remixer: remixer,
            grouping: grouping,
            bpm: bpm,
            musicalKey: musicalKey,
            trackNumber: trackNumber,
            totalTracks: totalTracks,
            discNumber: discNumber,
            totalDiscs: totalDiscs,
            year: year,
            date: date,
            publisherOrLabel: publisherOrLabel,
            copyright: copyright,
            encodedBy: encodedBy,
            isrc: isrc,
            duration: duration,
            artworkData: artworkData,
            artworkSourceIdentifier: artworkSourceIdentifier,
            updatedAt: updatedAt
        )
    }

    /// Собирает runtime snapshot для купленного iTunes-трека без BookmarkResolver и кэша метаданных.
    init(
        purchasedITunesTrack track: PurchasedITunesPlayableTrack,
        technicalMetadata: TrackTechnicalMetadata
    ) {
        let fallbackFileName = track.title ?? track.fileName

        self.init(
            trackId: track.trackId,
            fileName: track.fileName.isEmpty ? fallbackFileName : track.fileName,
            isAvailable: track.isAvailable,
            technicalMetadata: technicalMetadata,
            title: track.title,
            artist: track.artist,
            album: track.album,
            albumArtist: nil,
            genre: nil,
            comment: nil,
            composer: nil,
            conductor: nil,
            lyricist: nil,
            remixer: nil,
            grouping: nil,
            bpm: nil,
            musicalKey: nil,
            trackNumber: nil,
            totalTracks: nil,
            discNumber: nil,
            totalDiscs: nil,
            year: nil,
            date: nil,
            publisherOrLabel: nil,
            copyright: nil,
            encodedBy: nil,
            isrc: nil,
            duration: track.duration,
            artworkData: track.artworkData,
            artworkSourceIdentifier: track.artworkData.map {
                _ in ArtworkSourceIdentifier.mediaLibrary(trackId: track.trackId)
            },
            updatedAt: Date()
        )
    }
}
