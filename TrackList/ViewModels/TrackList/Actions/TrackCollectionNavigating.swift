//
//  TrackCollectionNavigating.swift
//  TrackList
//
//  Переход к заранее подготовленным значениям музыкальной коллекции.
//
//  Created by Pavel Fomin on 13.08.2026.
//

import Foundation

/// Открывает подготовленные цели музыкальной коллекции без повторного чтения metadata.
@MainActor
protocol TrackCollectionNavigating {
    /// Открывает артиста из сохранённой цели строки.
    func openArtist(target: TrackCollectionNavigationTarget)

    /// Открывает альбом из сохранённой цели строки.
    func openAlbum(target: TrackCollectionNavigationTarget)
}

/// Открывает значения коллекции по идентификатору трека для строк Library и Player.
@MainActor
protocol TrackCollectionIdentifierNavigating {
    /// Открывает значение артиста текущего трека.
    func openArtist(trackId: UUID)

    /// Открывает значение альбома текущего трека.
    func openAlbum(trackId: UUID)
}

extension TrackCollectionNavigationHandler: TrackCollectionIdentifierNavigating {}
