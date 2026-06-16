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

    /// Сохраняет треки конкретного треклиста.
    func saveTracks(_ tracks: [Track], for id: UUID) -> Bool
}
