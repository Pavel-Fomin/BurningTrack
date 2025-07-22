//
//  LibraryFolder.swift
//  TrackList
//
//  Представляет одну папку в фонотеке, включая подпапки и аудиофайлы
//  Created by Pavel Fomin on 27.06.2025.
//

import Foundation

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
        self.id = UUID()               /// Генерируем уникальный ID при создании (не зависит от содержимого)
        self.name = name               /// Отображаемое имя
        self.url = url                 /// Абсолютный путь к директории
        self.subfolders = subfolders   /// subfolders: Вложенные папки (по умолчанию — пусто)
        self.audioFiles = audioFiles   /// audioFiles: Файлы в текущей папке (по умолчанию — пусто)
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
