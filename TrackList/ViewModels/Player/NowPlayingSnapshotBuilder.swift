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

        if let purchasedTrack = track as? (any TrackDisplayable & PurchasedITunesTrackRepresentable),
           purchasedTrack.isPurchasedITunesRuntimeTrack {
            return makePurchasedITunesSnapshot(
                track: purchasedTrack,
                currentTime: currentTime,
                fallbackDuration: fallbackDuration,
                isPlaying: isPlaying
            )
        }

        let shouldShowTags = AppSettingsManager.shared.settings.visible.metadata.isTagReadingEnabled

        return NowPlayingSnapshot(
            title: shouldShowTags ? (runtimeSnapshot?.title ?? track.fileName) : track.fileName,
            artist: shouldShowTags ? (runtimeSnapshot?.artist ?? "") : "",
            album: shouldShowTags ? runtimeSnapshot?.album : nil,
            artwork: shouldShowTags ? artwork : nil,
            currentTime: currentTime,
            duration: runtimeSnapshot?.duration ?? fallbackDuration,
            isPlaying: isPlaying
        )
    }

    /// Собирает Now Playing snapshot для iTunes-трека из runtime-данных MediaPlayer.
    private func makePurchasedITunesSnapshot(
        track: any TrackDisplayable & PurchasedITunesTrackRepresentable,
        currentTime: TimeInterval,
        fallbackDuration: TimeInterval,
        isPlaying: Bool
    ) -> NowPlayingSnapshot {
        let title: String = {
            if track.title?.isEmpty == false {
                return track.title ?? ""
            }

            return track.fileName
        }()

        let artist: String = {
            if track.artist?.isEmpty == false {
                return track.artist ?? ""
            }

            return ""
        }()

        // Для экрана блокировки строим отдельный CGImage нужного размера из runtime-данных MediaPlayer.
        let artwork = track.artworkData.flatMap { data in
            makeThumbnail(
                from: data,
                maxPixel: ArtworkPurposeSizes.maxPixel(for: .nowPlaying)
            )
        }

        return NowPlayingSnapshot(
            title: title,
            artist: artist,
            album: track.album,
            artwork: artwork,
            currentTime: currentTime,
            duration: track.duration > 0 ? track.duration : fallbackDuration,
            isPlaying: isPlaying
        )
    }
}
