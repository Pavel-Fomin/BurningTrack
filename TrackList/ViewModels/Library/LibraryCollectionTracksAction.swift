//
//  LibraryCollectionTracksAction.swift
//  TrackList
//
//  Действия списка треков выбранного значения музыкальной коллекции.
//
//  Created by Pavel Fomin on 20.07.2026.
//

import Foundation

/// Описывает намерения пользователя на экране треков выбранного значения коллекции.
enum LibraryCollectionTracksAction {
    /// Запускает экспорт видимых музыкальных файлов в отображаемом порядке.
    case exportTracks([LibraryTrack])
}
