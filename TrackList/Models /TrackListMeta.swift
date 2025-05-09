//
//  TrackListMeta.swift
//  TrackList
//
//Модель метаинформации о плейлисте.
//
//  Используется для отображения списка всех плейлистов в интерфейсе,
//  а также для хранения базовой информации: идентификатор, название и дата создания.
//  Сами треки хранятся отдельно в файле tracklist_<UUID>.json.
//
//  Created by Pavel Fomin on 08.05.2025.
//

import Foundation

struct TrackListMeta: Codable, Identifiable {
    let id: UUID
    var name: String
    let createdAt: Date
}
