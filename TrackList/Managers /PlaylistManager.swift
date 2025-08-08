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
    @Published var tracks: [PlayerTrack] = []
    
    @Published var artworkByURL: [URL: UIImage] = [:]
    
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
                
                self.tracks = importedTracks.compactMap { PlayerTrack(from: $0) }
                
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
        let newTracks: [PlayerTrack] = await withTaskGroup(of: PlayerTrack?.self) { group in
            for url in urls {
                group.addTask {
                    do {
                        guard let bookmarkData = try? url.bookmarkData() else {
                            return nil}

                        let bookmarkBase64 = bookmarkData.base64EncodedString()
                        let metadata = try await MetadataParser.parseMetadata(from: url)

                        if let data = metadata.artworkData,
                           let image = UIImage(data: data) {
                            await MainActor.run {
                                self.artworkByURL[url] = image
                            }
                        }

                        return PlayerTrack(
                            id: UUID(),
                            url: url,
                            artist: metadata.artist,
                            title: metadata.title ?? url.deletingPathExtension().lastPathComponent,
                            duration: metadata.duration ?? 0,
                            fileName: url.lastPathComponent,
                            isAvailable: true,
                            bookmarkBase64: bookmarkBase64
                        )
                    } catch {
                        return nil
                    }
                }
            }

            var results: [PlayerTrack] = []
            for await result in group {
                if let track = result {
                    results.append(track)
                }
            }
            return results
        }
        
        // Обновляем треки и сохраняем
        let playerTracks: [PlayerTrack] = newTracks.compactMap { track in
            PlayerTrack(
                id: track.id,
                url: track.url,
                artist: track.artist,
                title: track.title,
                duration: track.duration,
                fileName: track.fileName,
                isAvailable: track.isAvailable,
                bookmarkBase64: track.bookmarkBase64
            )
        }
        
        self.tracks = playerTracks
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
        
        
        // MARK: - Удаление трека
        
        /// Удаляет трек и обновляет player.json
        func remove(at index: Int) {
            guard index >= 0 && index < tracks.count else { return }
            
            tracks.remove(at: index)
            saveToDisk()
        }
    }
    

extension PlayerTrack {
    init?(from imported: ImportedTrack) {
        guard let bookmarkBase64 = imported.bookmarkBase64,
              let bookmarkData = Data(base64Encoded: bookmarkBase64) else {
            return nil
        }

        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmarkData, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &isStale), !isStale else {
            return nil
        }

        self.init(
            id: imported.id,
            url: url,
            artist: imported.artist,
            title: imported.title,
            duration: imported.duration,
            fileName: imported.fileName,
            isAvailable: true,
            bookmarkBase64: bookmarkBase64
        )
    }
}
