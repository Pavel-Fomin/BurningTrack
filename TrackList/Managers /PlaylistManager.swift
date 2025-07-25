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
    
    /// Синглтон
    static let shared = PlaylistManager()
    
    /// Текущий плейлист плеера (из player.json)
    @Published var tracks: [Track] = []
    
    /// Имя JSON-файла, в котором хранится плейлист плеера
    private let fileName = "player.json"
    
    /// Инициализация — загружаем треки с диска
    private init() {
        loadFromDisk()
    }
    
    
// MARK: - Загружает треки из файла player.json
    
    /// Загружает список треков из player.json в /Documents
    func loadFromDisk() {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName) else {
            return
        }
        
        // Если файл не существует — создаём пустой плейлист
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
    
    /// Сохраняет текущий список треков в player.json в формате [ImportedTrack]
    func saveToDisk() {
        let importedTracks = tracks.map { $0.asImportedTrack() }
        
        do {
            let encoder = makePrettyJSONEncoder()
            let data = try encoder.encode(importedTracks)
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(fileName)
            try data.write(to: url, options: .atomic)
            print("💾 Сохранено \(tracks.count) треков в player.json")
        } catch {
            print("❌ Ошибка при сохранении player.json: \(error.localizedDescription)")
        }
    }
    
    
// MARK: - Импорт треков в плеер
    
    /// Импортирует список треков по URL-ам: парсит теги и добавляет в tracks
    /// - Parameter urls: Список локальных путей к файлам
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
        
        // Обновляем треки и сохраняем
        self.tracks.append(contentsOf: newTracks)
        saveToDisk()
    }
    
    
// MARK: - Экспорт треков
    
    /// Экспортирует все доступные треки (isAvailable == true) через ExportManager
    /// - Parameter folder: Папка — параметр зарезервирован, но не используется (в текущей реализации UIDocumentPicker сам запрашивает)
    func exportTracks(to folder: URL) {
        let availableTracks = tracks
            .filter { $0.isAvailable }
            .map { $0.asImportedTrack() }

        if availableTracks.isEmpty {
            
            return
        }

        if let topVC = UIApplication.topViewController() {
            ExportManager.shared.exportViaTempAndPicker(availableTracks, presenter: topVC)
        } else {
            
        }
    }
    
    /// Дублирующий метод экспорта (используется для отдельных вызовов или context menu)
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
    
    
    // MARK: - Очистка плеера

    /// Очищает плейлист плеера и обновляет player.json
    func clear() {
        tracks = []
        saveToDisk()
        print("🗑️ Плеер очищен")
    }
}
