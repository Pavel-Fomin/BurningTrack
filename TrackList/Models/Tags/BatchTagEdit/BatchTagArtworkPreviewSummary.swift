//
//  BatchTagArtworkPreviewSummary.swift
//  TrackList
//
//  Сводная информация по обложкам выбранных треков.
//
//  Created by Pavel Fomin on 25.05.2026.
//

import Foundation

/// Сводная информация по обложкам выбранных треков.
struct BatchTagArtworkPreviewSummary: Equatable {
    /// Количество выбранных треков.
    let selectedCount: Int
    /// Количество треков с обложками.
    let artworkCount: Int
    /// Количество треков без обложек.
    let missingArtworkCount: Int
}
