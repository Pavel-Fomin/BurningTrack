//
//  NowPlayingSnapshotBuilder.swift
//  TrackList
//
//  Сборщик snapshot для Control Center / Lock Screen.
//
//  Created by Pavel Fomin on 19.06.2026.
//

import Foundation
import CoreGraphics

/// Сборщик snapshot для Control Center / Lock Screen.
///
/// Не управляет AVPlayer.
/// Не применяет данные в MPNowPlayingInfoCenter.
/// Только собирает NowPlayingSnapshot из переданных данных.
@MainActor
final class NowPlayingSnapshotBuilder: NowPlayingSnapshotBuilding {

    /// Позволяет создавать builder как зависимость по умолчанию в init PlayerViewModel.
    nonisolated init() {}

    func makeSnapshot(
        track: any TrackDisplayable,
        runtimeSnapshot: TrackRuntimeSnapshot?,
        artwork: CGImage?,
        currentTime: TimeInterval,
        fallbackDuration: TimeInterval,
        isPlaying: Bool
    ) -> NowPlayingSnapshot {

        let shouldShowTags = AppSettingsManager.shared.settings.visible.metadata.isTagReadingEnabled

        return NowPlayingSnapshot(
            title: shouldShowTags ? (runtimeSnapshot?.title ?? track.fileName) : track.fileName,
            artist: shouldShowTags ? (runtimeSnapshot?.artist ?? "") : "",
            artwork: shouldShowTags ? artwork : nil,
            currentTime: currentTime,
            duration: runtimeSnapshot?.duration ?? fallbackDuration,
            isPlaying: isPlaying
        )
    }
}
