//
//  TrackListManaging.swift
//  TrackList
//
//  Контракт управления содержимым одного треклиста.
//
//  Created by Pavel Fomin on 15.06.2026.
//

import Foundation

@MainActor
protocol TrackListManaging {

    /// Загружает треки конкретного треклиста.
    func loadTracks(for id: UUID) throws -> [Track]

    /// Сохраняет треки конкретного треклиста и возвращает receipt только после SQLite persist.
    func saveTracks(_ tracks: [Track], for id: UUID) throws -> TrackListTracksSaveReceipt

    /// Сохраняет треки конкретного треклиста с явным выбором публикации точечных событий Favorites.
    func saveTracks(
        _ tracks: [Track],
        for id: UUID,
        publishesFavoritesEvents: Bool
    ) throws -> TrackListTracksSaveReceipt
}

extension TrackListManaging {

    /// Сохраняет содержимое через базовый контракт, если подмена не поддерживает отдельную публикацию Favorites.
    func saveTracks(
        _ tracks: [Track],
        for id: UUID,
        publishesFavoritesEvents: Bool
    ) throws -> TrackListTracksSaveReceipt {
        try saveTracks(tracks, for: id)
    }
}
