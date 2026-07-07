//
//  TrackCachedMetadata.swift
//  TrackList
//
//  Краткие metadata трека, прочитанные из SQLite.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

// Передаёт сохранённые SQLite metadata выше слоя базы без раскрытия DatabaseModel.
struct TrackCachedMetadata: Equatable, Identifiable {
    let trackId: UUID
    let title: String?
    let artist: String?
    let album: String?
    let duration: Double?
    let year: Int?
    let label: String?
    let genre: String?
    let comment: String?

    /// Идентификатор DTO совпадает с идентификатором трека.
    var id: UUID {
        trackId
    }
}
