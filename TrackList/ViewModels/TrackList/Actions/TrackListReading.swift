//
//  TrackListReading.swift
//  TrackList
//
//  Created by Pavel Fomin on 18.06.2026.
//

import Foundation

/// Предоставляет данные одного треклиста для action handlers.
@MainActor
protocol TrackListReading {
    /// Идентификатор текущего треклиста.
    var currentListId: UUID? { get }

    /// Название текущего треклиста.
    var name: String { get }

    /// Текущие треки треклиста.
    var tracks: [Track] { get }
}
