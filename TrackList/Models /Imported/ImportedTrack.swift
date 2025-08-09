//
//  ImportedTrack.swift
//  TrackList
//
//  Модель, представляющая импортированный трек.
//  Содержит путь к файлу, метаданные, bookmark, ID обложки.
//
//  Created by Pavel Fomin on 01.05.2025.
//

import Foundation
import UIKit

/// Представляет импортированный трек, сохраняемый в JSON.
/// Используется для восстановления доступа к файлу и отображения в списке.
struct ImportedTrack: Codable, Identifiable {
    let id: UUID                /// Уникальный идентификатор трека
    let fileName: String        /// Имя файла (например, "track1.mp3")
    let filePath: String        /// Путь к файлу (может быть устаревшим, используется fallback)
    var orderPrefix: String     /// Префикс порядка (например, "01")
    let title: String?          /// Название трека (если найдено в тегах)
    let artist: String?         /// Исполнитель
    let album: String?          /// Альбом
    let duration: Double        /// Длительность в секундах
    let bookmarkBase64: String? /// Сохранённый bookmark для доступа к файлу
    
    /// Проверяет, доступен ли файл по bookmark
    var isAvailable: Bool {
        guard let url = try? resolvedURL() else {
            return false
        }
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    /// Восстанавливает URL из base64 bookmark
    ///
    /// - Returns: URL к защищённому ресурсу
    /// - Throws: URLError, если bookmark некорректен или не может быть декодирован
    func resolvedURL() throws -> URL {
        guard let bookmarkBase64 = bookmarkBase64 else {
            throw URLError(.badURL, userInfo: ["reason": "bookmarkBase64 is nil"])
        }
        
        guard let bookmarkData = Data(base64Encoded: bookmarkBase64) else {
            throw URLError(.badURL, userInfo: ["reason": "bookmarkBase64 can't be decoded"])
        }
        
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [], 
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        
        if isStale {
            print("♻️ Bookmark устарел, желательно пересоздать")
        }
        
        return url
    }
}


extension ImportedTrack {
    func startAccessingIfNeeded() -> Bool {
        
        // Безопасно извлекаем bookmarkBase64
        guard let base64 = bookmarkBase64,
              let data = Data(base64Encoded: base64) else { return false }
        
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
            return url.startAccessingSecurityScopedResource()
        } catch {
            print("❌ Ошибка доступа к ImportedTrack: \(error)")
            return false
        }
    }
}

extension ImportedTrack: TrackDisplayable {
    var url: URL {
        (try? resolvedURL()) ?? URL(fileURLWithPath: filePath)
    }

    var artwork: UIImage? {
        // Предупреждение: async-функцию вызвать здесь нельзя
        nil
    }
}
