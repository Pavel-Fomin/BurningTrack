//
//  Track.swift
//  TrackList
//
//  Модель трека для воспроизведения и отображения.
//  Создаётся из ImportedTrack и содержит URL, обложку, флаг доступности
//
//  Created by Pavel Fomin on 01.05.2025.
//

import Foundation
import UIKit
import AVFoundation

// MARK: - Представляет один аудиотрек в приложении (после импорта)

struct Track: Identifiable {
    let id: UUID
    let url: URL
    let artist: String?
    let title: String?
    let duration: TimeInterval
    let fileName: String
    let artworkId: UUID?
    let isAvailable: Bool /// Флаг доступности трека
    
    
    // MARK: - Проверка доступности трека (обновление isAvailable)
    
    // Проверяет доступность файла вручную и возвращает новую копию трека
    func refreshAvailability() -> Track {
        var isAvailable = false
        

        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if accessGranted {
            do {
                // Пытаемся прочитать файл (без загрузки в память)
                let _ = try Data(contentsOf: url, options: [.mappedIfSafe])
                isAvailable = true
            } catch {
                print("🗑️ Файл не читается: \(error.localizedDescription)")
            }
        }

        return Track(
            id: self.id,
            url: self.url,
            artist: self.artist,
            title: self.title,
            duration: self.duration,
            fileName: self.fileName,
            artworkId: self.artworkId,
            isAvailable: isAvailable
        )
    }

    // MARK: - Загрузка трека из URL с помощью AVFoundation
    
    // Загружает метаданные трека через AVAsset и возвращает Track
    static func load(from url: URL) async throws -> Self {
        let asset = AVURLAsset(url: url)

        var artist = "Неизвестен"
        var trackName = url.deletingPathExtension().lastPathComponent
        var duration: TimeInterval = 0
        let available = FileManager.default.fileExists(atPath: url.path)
        
        //Проверка
        do {
            let metadata = try await asset.load(.commonMetadata)

            for item in metadata {
                if item.commonKey?.rawValue == "artist" {
                    if let value = try? await item.load(.stringValue) {
                        artist = value
                    }
                }

                if item.commonKey?.rawValue == "title" {
                    if let value = try? await item.load(.stringValue) {
                        trackName = value
                    }
                }
            }

            let cmDuration = try await asset.load(.duration)
            duration = CMTimeGetSeconds(cmDuration)

        } catch {
            print("Ошибка при чтении метаданных: \(error)")
        }

        return Self(
            id: UUID(),
            url: url,
            artist: artist,
            title: trackName,
            duration: duration,
            fileName: url.lastPathComponent,
            artworkId: nil,
            isAvailable: available
        )
    }
    // MARK: - Преобразование Track в ImportedTrack (для сохранения в JSON)
    
    // Конвертирует Track в ImportedTrack (для записи в JSON)
    func asImportedTrack() -> ImportedTrack {
        return ImportedTrack(
            id: self.id,
            fileName: self.fileName,
            filePath: self.url.path,
            orderPrefix: "",
            title: self.title,
            artist: self.artist,
            album: nil,
            duration: self.duration,
            artworkBase64: self.artwork?.pngData()?.base64EncodedString(),
            bookmarkBase64: try? self.url.bookmarkData().base64EncodedString(),
            artworkId: self.artworkId
        )
    }
}

// MARK: - Equatable: сравнение по URL

extension Track: Equatable {
    static func == (lhs: Track, rhs: Track) -> Bool {
        return lhs.url == rhs.url
    }
}

// MARK: - Соответствие TrackDisplayable

extension Track: TrackDisplayable { }


// MARK: - Инициализатор

extension Track {
    init(from libraryTrack: LibraryTrack) {
        self.init(
            id: libraryTrack.id,
            url: libraryTrack.url,
            artist: libraryTrack.artist,
            title: libraryTrack.title,
            duration: libraryTrack.duration,
            fileName: libraryTrack.fileName,
            artworkId: nil,
            isAvailable: libraryTrack.isAvailable
        )
    }
}
// MARK: - Вычисляемый аксессор

extension Track {
    var artwork: UIImage? {
        guard let artworkId else { return nil }
        return ArtworkManager.loadArtwork(id: artworkId)
    }
}


extension Track {
    init(from imported: ImportedTrack) {
        self.init(
            id: imported.id,
            url: URL(fileURLWithPath: imported.filePath),
            artist: imported.artist,
            title: imported.title ?? imported.fileName,
            duration: imported.duration,
            fileName: imported.fileName,
            artworkId: imported.artworkId,
            isAvailable: true // по умолчанию true, потом можно вызвать .refreshAvailability()
        )
    }
}
