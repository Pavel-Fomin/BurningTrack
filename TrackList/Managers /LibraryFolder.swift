//
//  LibraryFolder.swift
//  TrackList
//
//  Представляет одну папку в фонотеке, включая подпапки и аудиофайлы
//  Created by Pavel Fomin on 27.06.2025.
//

import Foundation
import CryptoKit

// MARK: - Модель для одной папки в библиотеке

/// Представляет папку с музыкой в фонотеке, включая вложенные папки и найденные аудиофайлы
struct LibraryFolder: Identifiable, Hashable {
    let id: UUID                     /// Уникальный ID папки (для SwiftUI и идентификации)
    let name: String                 /// Название папки (отображается в UI)
    let url: URL                     /// Путь к папке на устройстве
    var subfolders: [LibraryFolder]  /// Вложенные подпапки (рекурсивная структура)
    var audioFiles: [URL]            /// Список найденных аудиофайлов в этой папке (не включая подпапки)

    /// Инициализатор папки
    init(name: String, url: URL, subfolders: [LibraryFolder] = [], audioFiles: [URL] = []) {
        self.id = UUID.v5(from: url.standardizedFileURL.absoluteString)
        self.name = name
        self.url = url
        self.subfolders = subfolders
        self.audioFiles = audioFiles
    }
    
}


// MARK: - Утилиты

extension LibraryFolder {
    
    /// Рекурсивно возвращает все аудиофайлы, включая содержимое подпапок
    /// Используется для построения общего списка треков без вложенности
    func flattenedTracks() -> [URL] {
        var result = audioFiles
        for subfolder in subfolders {
            result.append(contentsOf: subfolder.flattenedTracks())
        }
        return result
    }
}


extension UUID {
    /// Стабильный UUID v5-подобного типа на основе строки (используется для URL)
    static func v5(from string: String) -> UUID {
        let data = Data(string.utf8)
        let hash = Insecure.MD5.hash(data: data)
        var bytes = [UInt8](repeating: 0, count: 16)
        for (i, b) in hash.enumerated().prefix(16) { bytes[i] = b }
        bytes[6] = (bytes[6] & 0x0F) | 0x50   // версия 5
        bytes[8] = (bytes[8] & 0x3F) | 0x80   // вариант RFC 4122
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
