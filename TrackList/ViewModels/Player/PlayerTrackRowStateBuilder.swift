//
//  PlayerTrackRowStateBuilder.swift
//  TrackList
//
//  Builder состояния строк плейлиста плеера.
//
//  Created by Pavel Fomin on 15.06.2026.
//

import Foundation
import UIKit

/// Собирает состояние строк плейлиста плеера.
///
/// Builder не выполняет действия,
/// не подписывается на изменения
/// и не управляет состоянием экрана.
@MainActor
final class PlayerTrackRowStateBuilder {

    // MARK: - Dependencies

    /// Провайдер обложек треков.
    private let artworkProvider: ArtworkProvider

    // MARK: - Инициализация

    init(artworkProvider: ArtworkProvider) {
        self.artworkProvider = artworkProvider
    }

    // MARK: - Public API

    /// Собирает состояния строк плеера.
    func makeRows(
        tracks: [PlayerTrack],
        currentQueueItemId: UUID?,
        isPlaying: Bool,
        snapshotsByTrackId: [UUID: TrackRuntimeSnapshot],
        highlightedRowId: UUID?,
        shouldShowTags: Bool,
        shouldShowFileFormat: Bool
    ) -> [PlayerTrackRowState] {
        tracks.map { track in
            let snapshot = snapshotsByTrackId[track.trackId]
            let isCurrent = track.id == currentQueueItemId

            return PlayerTrackRowState(
                id: track.id,
                trackId: track.trackId,
                track: track,
                isCurrent: isCurrent,
                isPlaying: isCurrent && isPlaying,
                isHighlighted: highlightedRowId == track.id,
                artwork: makeArtwork(
                    track: track,
                    trackId: track.trackId,
                    snapshot: snapshot,
                    shouldShowTags: shouldShowTags
                ),
                title: makeTitle(
                    track: track,
                    snapshot: snapshot,
                    shouldShowTags: shouldShowTags
                ),
                artist: makeArtist(
                    track: track,
                    snapshot: snapshot,
                    shouldShowTags: shouldShowTags
                ),
                currentFileName: snapshot?.fileName ?? track.fileName,
                renameArtist: snapshot?.artist,
                renameTitle: snapshot?.title,
                duration: snapshot?.duration ?? track.duration,
                showsFileFormat: shouldShowFileFormat
            )
        }
    }

    // MARK: - Private

    /// Формирует обложку строки плеера из runtime snapshot.
    private func makeArtwork(
        track: PlayerTrack,
        trackId: UUID,
        snapshot: TrackRuntimeSnapshot?,
        shouldShowTags: Bool
    ) -> UIImage? {
        if track.isPurchasedITunesRuntimeTrack {
            return track.artwork
        }

        guard shouldShowTags else { return nil }
        guard let data = snapshot?.artworkData else { return nil }

        return artworkProvider.image(
            trackId: trackId,
            artworkData: data,
            purpose: .trackList
        )
    }

    /// Формирует заголовок строки плеера.
    private func makeTitle(
        track: PlayerTrack,
        snapshot: TrackRuntimeSnapshot?,
        shouldShowTags: Bool
    ) -> String {
        if track.isPurchasedITunesRuntimeTrack {
            return track.title ?? track.fileName
        }

        guard shouldShowTags else { return track.fileName }
        return snapshot?.title ?? snapshot?.fileName ?? track.fileName
    }

    /// Формирует исполнителя строки плеера.
    private func makeArtist(
        track: PlayerTrack,
        snapshot: TrackRuntimeSnapshot?,
        shouldShowTags: Bool
    ) -> String {
        if track.isPurchasedITunesRuntimeTrack {
            return track.artist ?? ""
        }

        guard shouldShowTags else { return "" }
        return snapshot?.artist ?? ""
    }
}
