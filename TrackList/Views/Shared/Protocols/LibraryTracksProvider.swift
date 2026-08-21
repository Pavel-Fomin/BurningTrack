//
//  LibraryTracksProvider.swift
//  TrackList
//
//  Объявляет асинхронное получение треков для источников фонотеки.
//
//  Created by Pavel Fomin on 13.12.2025.
//

import Foundation


/// Provider передаёт только immutable display-модели, поэтому может безопасно обслуживать async feature-owner-ов.
protocol LibraryTracksProvider: Sendable {
    /// Возвращает треки для папки, значения раздела коллекции или общего списка фонотеки.
    func tracks(for source: LibraryTrackListSource) async -> [LibraryTrack]
}
