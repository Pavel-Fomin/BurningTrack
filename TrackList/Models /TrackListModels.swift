//
//  TrackListModels.swift
//  TrackList
//
//  Модель плейлиста, включающая список импортированных треков (ImportedTrack).
//  Используется при сохранении и загрузке данных из JSON
//
//  Created by Pavel Fomin on 27.04.2025.
//

import Foundation

/// Полноценный треклист: ID, название, дата создания, список треков
/// Хранится в файле tracklist_<UUID>.json
struct TrackList: Codable, Identifiable {
    let id: UUID                /// Уникальный идентификатор плейлиста
    var name: String            /// Название плейлиста
    let createdAt: Date         /// Дата создания
    var tracks: [ImportedTrack] /// Список треков внутри плейлиста
}
