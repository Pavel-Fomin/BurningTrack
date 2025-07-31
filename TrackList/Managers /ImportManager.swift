//
//  ImportManager.swift
//  TrackList
//
//  Импорт файлов, парсинг метаданных, сохранение в JSON
//
//  Created by Pavel Fomin on 28.04.2025.
//

import Foundation
import UniformTypeIdentifiers
import UIKit
import AVFoundation


// MARK: - Менеджер импорта треков

final class ImportManager {
    
    /// Импортирует список треков из URL-ов, парсит метаданные,
    /// сохраняет обложки и возвращает список ImportedTrack через completion
    /// - Parameters:
    /// - urls: массив URL-ов, полученных через fileImporter
    /// - listId: ID треклиста, в который производится импорт
    /// - completion: замыкание с массивом ImportedTrack
    func importTracks(from urls: [URL], to listId: UUID, completion: @escaping ([ImportedTrack]) -> Void) async {
        var importedTracks: [ImportedTrack] = []

        for (index, url) in urls.enumerated() {
            // Запрашиваем доступ к файлу (для sandbox и iCloud)
            guard url.startAccessingSecurityScopedResource() else {
                print("Нет доступа к файлу: \(url.lastPathComponent)")
                continue
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                // Сохраняем bookmark для последующего доступа
                let bookmarkData = try url.bookmarkData()
                let bookmarkBase64 = bookmarkData.base64EncodedString()

                // Парсим метаданные: title, artist, album, duration, artwork
                let metadata = try await MetadataParser.parseMetadata(from: url)
                let artworkBase64 = metadata.artworkData?.base64EncodedString()

                // Генерируем уникальный ID для трека (он же id для artwork)
                let trackId = UUID()

                // Название по умолчанию, если не найдено в тегах
                let fallbackTitle = url.deletingPathExtension().lastPathComponent
                
                // Формируем объект трека
                let newTrack = ImportedTrack(
                    id: trackId,
                    fileName: url.lastPathComponent,
                    filePath: url.path,
                    orderPrefix: String(format: "%02d", index + 1),
                    title: metadata.title ?? fallbackTitle,
                    artist: metadata.artist,
                    album: metadata.album,
                    duration: metadata.duration ?? 0,
                    bookmarkBase64: bookmarkBase64,
                )
                
                // Добавляем в итоговый список
                importedTracks.append(newTrack)

            } catch {
                print("Ошибка при импорте \(url.lastPathComponent): \(error)")
            }
        }

        print("Импортировано треков: \(importedTracks.count)")
        for t in importedTracks {print("– \(t.title ?? "без названия")")
        }
        
        // Отдаём результат через completion
        completion(importedTracks)
    }
}


// MARK: - Работа с JSON

extension ImportManager {
   
    /// Загружает список треков из JSON-файла по имени
    /// - Parameter name: имя JSON-файла (без расширения)
    /// - Returns: массив ImportedTrack, если файл успешно прочитан
    static func loadTrackList(named name: String) throws -> [ImportedTrack] {
        let decoder = JSONDecoder()
        
        // Путь к /Documents/TrackLists/<name>.json
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let trackListsFolder = documentsURL.appendingPathComponent("TrackLists")
        let jsonURL = trackListsFolder.appendingPathComponent("\(name).json")
        
        // Чтение и декодирование JSON
        let data = try Data(contentsOf: jsonURL)
        let tracks = try decoder.decode([ImportedTrack].self, from: data)
        print("Загружено треков: \(tracks.count) из файла \(jsonURL.lastPathComponent)")
        return tracks
    }
}
