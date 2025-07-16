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
    
    static let shared = PlaylistManager()
    
    @Published var tracks: [Track] = []
    
    private let fileName = "player.json"
    
    private init() {
        loadFromDisk()
    }
    
    
// MARK: - Загружает треки из файла player.json
    
    func loadFromDisk() {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName) else {
            print("❌ Не удалось получить путь к player.json")
            return
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("📄 player.json не найден — создаём пустой плейлист")
            self.tracks = []
            saveToDisk() // создаём файл
            return
        }
        
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                let data = try Data(contentsOf: url)
                let importedTracks = try JSONDecoder().decode([ImportedTrack].self, from: data)
                self.tracks = importedTracks.compactMap { Track(from: $0) }
                print("📥 Загружено \(tracks.count) треков из player.json")
            } else {
                print("📄 player.json не найден — создаём новый пустой")
                self.tracks = []
                saveToDisk()
            }
        } catch {
            print("⚠️ Ошибка при загрузке player.json: \(error.localizedDescription)")
        }
        
    }
    
    
// MARK: - Сохраняет треки в player.json
    
    func saveToDisk() {
        let importedTracks = tracks.map { $0.asImportedTrack() }
        
        do {
            let data = try JSONEncoder().encode(importedTracks)
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(fileName)
            try data.write(to: url, options: .atomic)
            print("💾 Сохранено \(tracks.count) треков в player.json")
        } catch {
            print("❌ Ошибка при сохранении player.json: \(error.localizedDescription)")
        }
    }
    
    
// MARK: - Импорт треков в плеер
    
    func importTracks(from urls: [URL]) async {
        let newTracks: [Track] = await withTaskGroup(of: Track?.self) { group in
            for url in urls {
                group.addTask {
                    do {
                        let metadata = try await MetadataParser.parseMetadata(from: url)
                        return Track(
                            id: UUID(),
                            url: url,
                            artist: metadata.artist,
                            title: metadata.title ?? url.deletingPathExtension().lastPathComponent,
                            duration: metadata.duration ?? 0,
                            fileName: url.lastPathComponent,
                            artworkId: nil,
                            isAvailable: true
                        )
                    } catch {
                        print("⚠️ Ошибка парсинга: \(error.localizedDescription)")
                        return nil
                    }
                }
            }
           
            var results: [Track] = []
            for await result in group {
                if let track = result {
                    results.append(track)
                }
            }
            return results
        }
        
        // ВНЕ taskGroup
        self.tracks.append(contentsOf: newTracks)
        saveToDisk()
    }
    
    // MARK: - Экспорт треков
    
    func exportTracks(to folder: URL) {
        let availableTracks = tracks
            .filter { $0.isAvailable }
            .map { $0.asImportedTrack() }

        if availableTracks.isEmpty {
            print("⚠️ Нет доступных треков для экспорта")
            return
        }

        if let topVC = UIApplication.topViewController() {
            ExportManager.shared.exportViaTempAndPicker(availableTracks, presenter: topVC)
        } else {
            print("❌ Не удалось найти topViewController")
        }
    }
    
    
    func exportCurrentTracks(to folder: URL) {
        let availableTracks = tracks
            .filter { $0.isAvailable }
            .map { $0.asImportedTrack() }

        guard !availableTracks.isEmpty else {
            print("⚠️ Нет доступных треков для экспорта")
            return
        }

        if let topVC = UIApplication.topViewController() {
            ExportManager.shared.exportViaTempAndPicker(availableTracks, presenter: topVC)
        }
    }
}
