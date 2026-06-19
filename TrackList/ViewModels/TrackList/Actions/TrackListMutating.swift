//
//  TrackListMutating.swift
//  TrackList
//
//  Created by Pavel Fomin on 18.06.2026.
//

import Foundation

/// Выполняет изменения состава и порядка треков одного треклиста.
@MainActor
protocol TrackListMutating {
    /// Текущие треки треклиста.
    var tracks: [Track] { get }

    /// Удаляет трек из треклиста по индексу.
    func removeTrack(at offsets: IndexSet)

    /// Меняет порядок треков.
    func moveTrack(
        from source: IndexSet,
        to destination: Int
    )
}
