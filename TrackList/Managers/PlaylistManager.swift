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
        let items = tracks.map {
            PlayerFileItem(queueItemId: $0.queueItemId, trackId: $0.trackId)
        }
        return saveToDisk(items: items)
    }
    
    // MARK: - Добавление треков в плеер
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
