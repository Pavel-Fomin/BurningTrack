//
//  TrackListMeta.swift
//  TrackList
//
//  Метаданные пользовательского треклиста без состава его треков.
//
//  Используется для отображения списка плейлистов и хранения:
//  - уникального ID,
//  - названия,
//  - даты создания,
//  - назначения треклиста.
//
//  Сами треки этого плейлиста хранятся в SQLite-таблице tracklist_tracks.
//
//
//  Created by Pavel Fomin on 08.05.2025.
//

import Foundation

struct TrackListMeta: Identifiable {
    let id: UUID
    var name: String
    let createdAt: Date
    let kind: TrackListKind
}
