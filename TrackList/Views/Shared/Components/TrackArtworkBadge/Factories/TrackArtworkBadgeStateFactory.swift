//
//  TrackArtworkBadgeStateFactory.swift
//  TrackList
//
//  Фабрика presentation-состояния бейджа обложки.
//
//  Created by Pavel Fomin on 30.07.2026.
//

import Foundation

/// Централизованно сопоставляет источник трека и состояние «Избранного» с одним бейджем.
struct TrackArtworkBadgeStateFactory: TrackArtworkBadgeStateBuilding {

    /// Внешний источник остаётся единственным отображаемым знаком и получает состояние «Избранного».
    func makeState(
        source: TrackSource,
        isFavorite: Bool
    ) -> TrackArtworkBadgeState {
        switch source {
        case .library, .imported:
            return isFavorite ? .favorite : .hidden

        case .purchasedITunes:
            return .source(
                .apple,
                isFavorite: isFavorite
            )
        }
    }
}
