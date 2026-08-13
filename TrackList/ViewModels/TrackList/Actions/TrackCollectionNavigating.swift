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
