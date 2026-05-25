//
//  BatchTagArtworkActionTarget.swift
//  TrackList
//
//  Цель действия с обложкой.
//
//  Created by Pavel Fomin on 25.05.2026.
//

import Foundation

/// Цель действия с обложкой.
enum BatchTagArtworkActionTarget: Equatable {
    /// Действие применяется ко всей выбранной группе треков.
    case summary
    /// Действие применяется к одному треку.
    case track(UUID)
}
