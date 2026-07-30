//
//  TrackArtworkBadgeStateBuilding.swift
//  TrackList
//
//  Контракт построения presentation-состояния бейджа обложки.
//
//  Created by Pavel Fomin on 30.07.2026.
//

import Foundation

/// Преобразует нормализованные данные трека в независимое от домена состояние бейджа.
protocol TrackArtworkBadgeStateBuilding {
    /// Возвращает единственное визуальное состояние для обложки трека.
    func makeState(
        source: TrackSource,
        isFavorite: Bool
    ) -> TrackArtworkBadgeState
}
