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
    /// Общий размер исходных обложек в байтах.
    let totalArtworkSizeBytes: Int

    init(
        selectedCount: Int,
        artworkCount: Int,
        missingArtworkCount: Int,
        totalArtworkSizeBytes: Int = 0
    ) {
        self.selectedCount = selectedCount
        self.artworkCount = artworkCount
        self.missingArtworkCount = missingArtworkCount
        self.totalArtworkSizeBytes = totalArtworkSizeBytes
    }
}
