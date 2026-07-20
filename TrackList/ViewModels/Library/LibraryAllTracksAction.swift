//
//  LibraryAllTracksAction.swift
//  TrackList
//
//  Действия экрана общего списка треков фонотеки.
//
//  Created by Pavel Fomin on 20.07.2026.
//

import Foundation

/// Описывает намерения пользователя на экране всех треков фонотеки.
enum LibraryAllTracksAction {
    /// Запускает экспорт видимых музыкальных файлов в отображаемом порядке.
    case exportTracks([LibraryTrack])
}
