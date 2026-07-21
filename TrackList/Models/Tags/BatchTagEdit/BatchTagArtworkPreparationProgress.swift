//
//  BatchTagArtworkPreparationProgress.swift
//  TrackList
//
//  Прогресс подготовки обложек перед сохранением.
//
//  Created by Pavel Fomin on 12.06.2026.
//

import Foundation

/// Прогресс подготовки обложек перед сохранением.
struct BatchTagArtworkPreparationProgress: Equatable {
    let current: Int   /// Количество подготовленных обложек.
    let total: Int     /// Общее количество обложек для подготовки.

}
