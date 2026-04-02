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
    
    private struct PlayerFile: Codable { let trackIds: [UUID]
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
            let decoded = try JSONDecoder().decode(PlayerFile.self, from: data)
            PersistentLogger.log("📥 PlaylistManager: decoded player.json ids=\(decoded.trackIds.count)")
            Task {
                await loadTracks(from: decoded.trackIds)
            }
        } catch {
            print("⚠️ Ошибка загрузки player.json: \(error)")
            PersistentLogger.log("⚠️ PlaylistManager: load error \(error)")
            saveEmptyFile()
        }
    }

    private func saveEmptyFile() {
        saveToDisk(trackIds: [])
        self.tracks = []
    }

    // MARK: - Превращение trackId → PlayerTrack

    private func makePlayerTrack(from id: UUID) async -> PlayerTrack {

        // Пытаемся получить URL
        guard let url = await BookmarkResolver.url(forTrack: id) else {
            return PlayerTrack(
                id: id,
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
            id: id,
            title: title,
            artist: artist,
            duration: duration,
            fileName: fileName,
            isAvailable: isAvailable
        )
    }

    // MARK: - Загрузка треков по массиву ID

    private func loadTracks(from ids: [UUID]) async {
        var result: [PlayerTrack] = []

        for id in ids {
            let track = await makePlayerTrack(from: id)
            result.append(track)
        }

        self.tracks = result

        let availableCount = result.filter { $0.isAvailable }.count
        print("📥 Загружено \(result.count) треков в плеер (доступно: \(availableCount))")
        PersistentLogger.log("📥 PlaylistManager: loaded tracks=\(result.count)")
    }

    // MARK: - Сохранение player.json

    private func saveToDisk(trackIds: [UUID]) {
        guard let url = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first?
            .appendingPathComponent(fileName)
        else { return }

        let file = PlayerFile(trackIds: trackIds)
        do {
            let data = try JSONEncoder().encode(file)
            try data.write(to: url, options: .atomic)
            print("💾 Сохранён player.json (\(trackIds.count) ids)")
        } catch {
            print("❌ Ошибка сохранения player.json: \(error)")
        }
    }

    func saveToDisk() {
        let ids = tracks.map { $0.id }
        saveToDisk(trackIds: ids)
    }

    // MARK: - Добавление треков в плеер

    func addTracks(ids: [UUID]) async {
        for id in ids {
            let track = await makePlayerTrack(from: id)
            tracks.append(track)
        }
        saveToDisk()
    }

    // MARK: - Удаление треков

    func remove(at index: Int) {
        guard index < tracks.count else { return }
        tracks.remove(at: index)
        saveToDisk()
    }

    func clear() {
        tracks = []
        saveToDisk()
    }
}
