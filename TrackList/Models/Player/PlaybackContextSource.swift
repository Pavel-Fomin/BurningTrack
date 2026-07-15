//
//  PlaybackContextSource.swift
//  TrackList
//
//  Источник контекста воспроизведения для постоянного восстановления.
//
//  Created by Pavel Fomin on 15.07.2026.
//

import Foundation

/// Описывает источник, из которого был запущен текущий трек.
enum PlaybackContextSource: Equatable {
    /// Общая очередь плеера без отдельного идентификатора источника.
    case playerQueue
    /// Пользовательский треклист, который нужно перечитать из SQLite после запуска приложения.
    case trackList(id: UUID)
    /// Конкретная прикреплённая или вложенная папка фонотеки.
    case libraryFolder(id: UUID)
    /// Корневой список всех локальных треков фонотеки.
    case libraryRoot
    /// Выбранное значение категории музыкальной коллекции.
    case libraryCollection(
        category: LibraryCollectionCategory,
        rawValue: String,
        artistKey: String?
    )
}
