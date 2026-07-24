//
//  TrackCollectionNavigationTarget.swift
//  TrackList
//
//  Цель перехода из контекстного меню трека к значению музыкальной коллекции.
//
//  Created by Pavel Fomin on 24.07.2026.
//

import Foundation

/// Готовые значения сохранённых metadata, доступные для перехода к артисту и альбому.
struct TrackCollectionNavigationTarget: Equatable {
    /// Значение для раздела артистов.
    let artist: String?
    /// Значение для раздела альбомов.
    let album: String?
    /// Дополнительный ключ исполнителя для разделения одноимённых альбомов.
    let albumArtistKey: String?

    /// Использует каноничные правила коллекции для подготовки значений сохранённых metadata.
    init(metadata: TrackCachedMetadata) {
        artist = LibraryCollectionCategory.artists.metadataValue(from: metadata)
        album = LibraryCollectionCategory.albums.metadataValue(from: metadata)
        albumArtistKey = LibraryCollectionCategory.albums.albumArtistKey(from: metadata)
    }
}
