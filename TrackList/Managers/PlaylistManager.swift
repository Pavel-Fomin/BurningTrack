//
//  PlaylistManager.swift
//  TrackList
//
//  Загружает и хранит треки из player.json
//
//  Created by Pavel Fomin on 15.07.2025.
//
import Foundation
import SwiftUI
@MainActor
final class PlaylistManager: ObservableObject {
    
    @Published var tracks: [PlayerTrack] = []
    var onTracksChanged: (([PlayerTrack]) -> Void)?
    
    static let shared = PlaylistManager()
    private let fileName = "player.json"
    
    private struct PlayerFile: Codable {
        let items: [PlayerFileItem]
    }
    private struct PlayerFileItem: Codable {
        let queueItemId: UUID
        let trackId: UUID
        let title: String?
        let artist: String?
        let album: String?
        let artworkData: Data?
        let duration: Double?
        let fileName: String?
        let isAvailable: Bool?
        let source: TrackSource
        let assetURL: URL?

        private enum CodingKeys: String, CodingKey {
            case queueItemId
            case trackId
            case title
            case artist
            case album
            case artworkData
            case duration
            case fileName
            case isAvailable
            case source
            case assetURL
        }

        /// Создаёт файловую запись очереди с сохранением совместимости старого формата.
        init(
            queueItemId: UUID,
            trackId: UUID,
            title: String? = nil,
            artist: String? = nil,
            album: String? = nil,
            artworkData: Data? = nil,
            duration: Double? = nil,
            fileName: String? = nil,
            isAvailable: Bool? = nil,
            source: TrackSource = .library,
            assetURL: URL? = nil
        ) {
            self.queueItemId = queueItemId
            self.trackId = trackId
            self.title = title
            self.artist = artist
            self.album = album
            self.artworkData = artworkData
            self.duration = duration
            self.fileName = fileName
            self.isAvailable = isAvailable
            self.source = source
            self.assetURL = assetURL
        }

        /// Сохраняет iTunes-метаданные и текущую обложку только для iTunes-источника.
        init(track: PlayerTrack) {
            self.init(
                queueItemId: track.queueItemId,
                trackId: track.trackId,
                title: track.title,
                artist: track.artist,
                album: track.album,
                artworkData: track.source == .purchasedITunes ? track.artworkData : nil,
                duration: track.duration,
                fileName: track.fileName,
                isAvailable: track.isAvailable,
                source: track.source,
                assetURL: track.assetURL
            )
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.queueItemId = try container.decode(UUID.self, forKey: .queueItemId)
            self.trackId = try container.decode(UUID.self, forKey: .trackId)
            self.title = try container.decodeIfPresent(String.self, forKey: .title)
            self.artist = try container.decodeIfPresent(String.self, forKey: .artist)
            self.album = try container.decodeIfPresent(String.self, forKey: .album)
            let decodedSource = try container.decodeIfPresent(TrackSource.self, forKey: .source) ?? .library
            // Обложку восстанавливаем только для iTunes-очереди, где нет файловой цепочки метаданных.
            self.artworkData = decodedSource == .purchasedITunes
                ? try container.decodeIfPresent(Data.self, forKey: .artworkData)
                : nil
            self.duration = try container.decodeIfPresent(Double.self, forKey: .duration)
            self.fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
            self.isAvailable = try container.decodeIfPresent(Bool.self, forKey: .isAvailable)
            self.source = decodedSource
            self.assetURL = try container.decodeIfPresent(URL.self, forKey: .assetURL)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(queueItemId, forKey: .queueItemId)
            try container.encode(trackId, forKey: .trackId)
            try container.encodeIfPresent(title, forKey: .title)
            try container.encodeIfPresent(artist, forKey: .artist)
            try container.encodeIfPresent(album, forKey: .album)
            if source == .purchasedITunes {
                // Это единственный источник обложки для восстановленной iTunes-очереди плеера.
                try container.encodeIfPresent(artworkData, forKey: .artworkData)
            }
            try container.encodeIfPresent(duration, forKey: .duration)
            try container.encodeIfPresent(fileName, forKey: .fileName)
            try container.encodeIfPresent(isAvailable, forKey: .isAvailable)
            try container.encode(source, forKey: .source)
            try container.encodeIfPresent(assetURL, forKey: .assetURL)
        }
    }
    private struct LegacyPlayerFile: Codable {
        let trackIds: [UUID]
    }
    
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onLibraryAccessRestored),
            name: .libraryAccessRestored,
            object: nil
        )
        
        loadFromDisk()
    }
    
    @objc private func onLibraryAccessRestored() {
        print("🔔 PlaylistManager: libraryAccessRestored → reloadFromDisk")
        loadFromDisk()
    }
    
    // MARK: - Загрузка player.json
    func loadFromDisk() {
        guard let url = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first?
            .appendingPathComponent(fileName)
        else { return }
        guard FileManager.default.fileExists(atPath: url.path) else {
            PersistentLogger.log("📄 PlaylistManager: player.json missing → creating empty")
            print("📄 player.json не найден — создаём пустой")
            saveEmptyFile()
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let items = try decodePlayerItems(from: data)
            PersistentLogger.log("📥 PlaylistManager: decoded player.json items=\(items.count)")
            Task {
                await loadTracks(from: items)
            }
        } catch {
            print("⚠️ Ошибка загрузки player.json: \(error)")
            PersistentLogger.log("⚠️ PlaylistManager: load error \(error)")
            saveEmptyFile()
        }
    }
    private func decodePlayerItems(from data: Data) throws -> [PlayerFileItem] {
        if let file = try? JSONDecoder().decode(PlayerFile.self, from: data) {
            return file.items
        }
        let legacyFile = try JSONDecoder().decode(LegacyPlayerFile.self, from: data)
        return legacyFile.trackIds.map { trackId in
            PlayerFileItem(queueItemId: UUID(), trackId: trackId)
        }
    }
    private func saveEmptyFile() {
        saveToDisk(items: [])
        self.tracks = []
    }
    
    // MARK: - Превращение trackId → PlayerTrack
    private func makePlayerTrack(from item: PlayerFileItem) async -> PlayerTrack {
        if item.source == .purchasedITunes {
            return makePurchasedITunesPlayerTrack(from: item)
        }

        // Пытаемся получить URL
        guard let url = await BookmarkResolver.url(forTrack: item.trackId) else {
            return PlayerTrack(
                queueItemId: item.queueItemId,
                trackId: item.trackId,
                title: "Недоступно",
                artist: nil,
                duration: 0,
                fileName: "Unknown",
                isAvailable: false
            )
        }
        let fileName = url.lastPathComponent
        let metadata = try? await RuntimeMetadataParser.parseMetadata(from: url)
        let title = metadata?.title ?? url.deletingPathExtension().lastPathComponent
        let artist = metadata?.artist
        let duration = metadata?.duration ?? 0
        let isAvailable = true
        return PlayerTrack(
            queueItemId: item.queueItemId,
            trackId: item.trackId,
            title: title,
            artist: artist,
            duration: duration,
            fileName: fileName,
            isAvailable: isAvailable
        )
    }

    /// Восстанавливает элемент очереди iTunes без обращения к BookmarkResolver.
    private func makePurchasedITunesPlayerTrack(from item: PlayerFileItem) -> PlayerTrack {
        guard let assetURL = item.assetURL else {
            return PlayerTrack(
                queueItemId: item.queueItemId,
                trackId: item.trackId,
                title: item.title ?? "Недоступно",
                artist: item.artist,
                album: item.album,
                artworkData: item.artworkData,
                duration: item.duration ?? 0,
                fileName: item.fileName ?? "Unknown",
                isAvailable: false,
                source: .purchasedITunes,
                assetURL: nil
            )
        }

        return PlayerTrack(
            queueItemId: item.queueItemId,
            trackId: item.trackId,
            title: item.title,
            artist: item.artist,
            album: item.album,
            artworkData: item.artworkData,
            duration: item.duration ?? 0,
            fileName: item.fileName ?? item.title ?? assetURL.lastPathComponent,
            isAvailable: item.isAvailable ?? true,
            source: .purchasedITunes,
            assetURL: assetURL
        )
    }
    
    // MARK: - Загрузка треков по элементам очереди
    private func loadTracks(from items: [PlayerFileItem]) async {
        var result: [PlayerTrack] = []
        for item in items {
            let track = await makePlayerTrack(from: item)
            result.append(track)
        }
        self.tracks = result
        let availableCount = result.filter { $0.isAvailable }.count
        print("📥 Загружено \(result.count) треков в плеер (доступно: \(availableCount))")
        PersistentLogger.log("📥 PlaylistManager: loaded tracks=\(result.count)")
    }
    
    // MARK: - Сохранение player.json
    @discardableResult
    private func saveToDisk(items: [PlayerFileItem]) -> Bool {
        guard let url = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first?
            .appendingPathComponent(fileName)
        else {
            return false
        }
        let file = PlayerFile(items: items)
        do {
            let data = try JSONEncoder().encode(file)
            try data.write(to: url, options: .atomic)
            print("💾 Сохранён player.json (\(items.count) items)")
            return true
        } catch {
            print("❌ Ошибка сохранения player.json: \(error)")
            return false
        }
    }
    @discardableResult
    func saveToDisk() -> Bool {
        let items = tracks.map { PlayerFileItem(track: $0) }
        return saveToDisk(items: items)
    }
    
    // MARK: - Добавление треков в плеер
    @discardableResult
    func addTracks(_ tracksToAdd: [PlayerTrack]) -> Bool {
        guard !tracksToAdd.isEmpty else { return true }

        // Откат нужен, чтобы runtime-очередь не расходилась с player.json при ошибке записи.
        let previousTracks = tracks
        tracks.append(contentsOf: tracksToAdd)

        guard saveToDisk() else {
            tracks = previousTracks
            return false
        }

        return true
    }

    @discardableResult
    func addTracks(ids: [UUID]) async -> Bool {
        for trackId in ids {
            let item = PlayerFileItem(queueItemId: UUID(), trackId: trackId)
            let track = await makePlayerTrack(from: item)
            tracks.append(track)
        }
        return saveToDisk()
    }
    
    // MARK: - Удаление треков
    @discardableResult
    func remove(at index: Int) -> Bool {
        guard index < tracks.count else { return false }
        tracks.remove(at: index)
        return saveToDisk()
    }
    @discardableResult
    func clear() -> Bool {
        tracks = []
        return saveToDisk()
    }
}
