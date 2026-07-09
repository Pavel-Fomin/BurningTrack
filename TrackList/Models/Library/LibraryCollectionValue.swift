//
//  LibraryCollectionValue.swift
//  TrackList
//
//  Значение раздела музыкальной коллекции.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

// Описывает одно значение внутри раздела коллекции с дополнительными данными для специальных строк.
struct LibraryCollectionValue: Identifiable, Hashable {
    /// Стабильный идентификатор строки внутри конкретного раздела.
    let id: String
    /// Раздел коллекции, к которому относится значение.
    let category: LibraryCollectionCategory
    /// Название для отображения в списке.
    let title: String
    /// Исходное значение metadata, используемое для фильтрации треков.
    let rawValue: String
    /// Количество треков с таким значением metadata.
    let tracksCount: Int
    /// Исполнитель для album-строки; остальные разделы оставляют поле пустым.
    let artist: String?
    /// Год для album-строки; остальные разделы оставляют поле пустым.
    let year: Int?
    /// Трек-представитель альбома, по которому можно лениво запросить runtime-обложку.
    let representativeTrackId: UUID?
    /// Физические id треков значения, нужные для определения текущего воспроизведения внутри альбома.
    let trackIds: [UUID]

    init(
        id: String,
        category: LibraryCollectionCategory,
        title: String,
        rawValue: String,
        tracksCount: Int,
        artist: String? = nil,
        year: Int? = nil,
        representativeTrackId: UUID? = nil,
        trackIds: [UUID] = []
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.rawValue = rawValue
        self.tracksCount = tracksCount
        self.artist = artist
        self.year = year
        self.representativeTrackId = representativeTrackId
        self.trackIds = trackIds
    }
}
