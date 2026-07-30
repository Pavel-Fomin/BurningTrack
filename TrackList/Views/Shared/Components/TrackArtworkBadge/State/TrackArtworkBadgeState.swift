//
//  TrackArtworkBadgeState.swift
//  TrackList
//
//  Presentation-состояние бейджа поверх обложки трека.
//
//  Created by Pavel Fomin on 30.07.2026.
//

import Foundation

/// Описывает единственный бейдж, отображаемый поверх обложки трека.
enum TrackArtworkBadgeState: Equatable {
    /// Бейдж не требуется для обычного локального трека.
    case hidden
    /// Локальный или импортированный трек находится в «Избранном».
    case favorite
    /// Внешний источник имеет приоритет над отдельным символом «Избранного».
    case source(
        TrackArtworkSourceBadge,
        isFavorite: Bool
    )
}

/// Описывает логотип внешнего источника без дублирования состояний избранного.
enum TrackArtworkSourceBadge: Equatable {
    /// Купленный трек из системной медиатеки Apple.
    case apple
}
