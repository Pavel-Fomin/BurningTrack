//
//  ImportManager.swift
//  TrackList

//  Импорт файлов, парсинг метаданных, сохранение в JSON
//
//  Created by Pavel Fomin on 28.04.2025.
//

import Foundation
import UniformTypeIdentifiers
import UIKit
import AVFoundation

// MARK: - Менеджер импорта треков в приложение
final class ImportManager {
    
    // MARK: - Импорт треков и сохранение в JSON
    func importTracks(from urls: [URL], to listId: UUID, completion: @escaping ([ImportedTrack]) -> Void) {
        var importedTracks: [ImportedTrack] = []

        for (index, url) in urls.enumerated() {
            guard url.startAccessingSecurityScopedResource() else {
                print("🚫 Нет доступа к \(url.lastPathComponent)")
                continue
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                // Чтение bookmark
                let bookmarkData = try url.bookmarkData()
                let bookmarkBase64 = bookmarkData.base64EncodedString()

                // Парсинг метаданных
                let parsed = try MetadataParser.parseMetadata(from: url)

                let newTrack = ImportedTrack(
                    id: UUID(),
                    fileName: url.lastPathComponent,
                    filePath: url.path,
                    orderPrefix: String(format: "%02d", index + 1),
                    title: parsed.title,
                    artist: parsed.artist,
                    album: parsed.album,
                    duration: parsed.duration ?? 0,
                    artworkBase64: parsed.artworkData?.base64EncodedString(),
                    bookmarkBase64: bookmarkBase64
                )

                importedTracks.append(newTrack)

            } catch {
                print("❌ Ошибка парсинга \(url.lastPathComponent): \(error)")
            }
        }

        print("📋 Все треки импортированы: \(importedTracks.count) шт.")
        for t in importedTracks {
            print("– \(t.title ?? "без названия")")
        }
       
        completion(importedTracks)
      }
    }

// MARK: - Работа с путями и чтением JSON-файлов
extension ImportManager {
    
    // MARK: - Загрузить треки из указанного JSON-файла
    static func loadTrackList(named name: String) throws -> [ImportedTrack] {
        print("📥 loadTrackList() вызван для списка: \(name)")
        let decoder = JSONDecoder()

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let trackListsFolder = documentsURL.appendingPathComponent("TrackLists")
        let jsonURL = trackListsFolder.appendingPathComponent("\(name).json")

        let data = try Data(contentsOf: jsonURL)
        let tracks = try decoder.decode([ImportedTrack].self, from: data)
        print("📄 Загружено треков: \(tracks.count) из \(jsonURL.lastPathComponent)")
        return tracks
    }
}
