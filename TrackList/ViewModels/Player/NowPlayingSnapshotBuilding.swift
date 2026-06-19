//
//  NowPlayingSnapshotBuilding.swift
//  TrackList
//
//  Абстракция сборки snapshot для Control Center / Lock Screen.
//
//  Created by Pavel Fomin on 19.06.2026.
//

import Foundation
import CoreGraphics

/// Собирает snapshot для Control Center / Lock Screen.
@MainActor
protocol NowPlayingSnapshotBuilding {
    /// Возвращает готовый NowPlayingSnapshot для текущего трека.
    func makeSnapshot(
        track: any TrackDisplayable,
        runtimeSnapshot: TrackRuntimeSnapshot?,
        artwork: CGImage?,
        currentTime: TimeInterval,
        fallbackDuration: TimeInterval,
        isPlaying: Bool
    ) -> NowPlayingSnapshot
}
