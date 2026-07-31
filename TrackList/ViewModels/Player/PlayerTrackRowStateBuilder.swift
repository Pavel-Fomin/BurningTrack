//
//  PlayerTrackRowStateBuilder.swift
//  TrackList
//
//  Builder состояния строк плейлиста плеера.
//
//  Created by Pavel Fomin on 15.06.2026.
//

import Foundation

/// Собирает состояние строк плейлиста плеера.
///
/// Builder не выполняет действия,
/// не подписывается на изменения
/// и не управляет состоянием экрана.
@MainActor
final class PlayerTrackRowStateBuilder {

    /// Фабрика централизует сопоставление источника и «Избранного» с бейджем.
    private let artworkBadgeStateFactory: any TrackArtworkBadgeStateBuilding

    // MARK: - Инициализация

    init(
        artworkBadgeStateFactory: any TrackArtworkBadgeStateBuilding = TrackArtworkBadgeStateFactory()
    ) {
        self.artworkBadgeStateFactory = artworkBadgeStateFactory
    }

    // MARK: - Public API

    /// Собирает состояния строк плеера.
    func makeRows(
        tracks: [PlayerTrack],
        currentQueueItemId: UUID?,
        isPlaying: Bool,
        favoriteTrackIds: Set<UUID>,
        snapshotsByTrackId: [UUID: TrackRuntimeSnapshot],
        collectionNavigationTargetsByTrackId: [UUID: TrackCollectionNavigationTarget],
        highlightedRowId: UUID?,
        shouldShowTags: Bool,
        shouldShowFileFormat: Bool
    ) -> [PlayerTrackRowState] {
        tracks.map { track in
            let snapshot = snapshotsByTrackId[track.trackId]
            let isCurrent = track.id == currentQueueItemId
            let isFavorite = favoriteTrackIds.contains(track.trackId)

            return PlayerTrackRowState(
                id: track.id,
                trackId: track.trackId,
                track: track,
                isCurrent: isCurrent,
                isPlaying: isCurrent && isPlaying,
                isHighlighted: highlightedRowId == track.id,
                isFavorite: isFavorite,
                artworkRequest: makeArtworkRequest(
                    track: track,
                    trackId: track.trackId,
                    snapshot: snapshot,
                    shouldShowTags: shouldShowTags
                ),
                artworkBadgeState: artworkBadgeStateFactory.makeState(
                    source: track.source,
                    isFavorite: isFavorite
                ),
                collectionNavigationTarget: collectionNavigationTargetsByTrackId[track.trackId],
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

    /// Формирует лёгкий запрос обложки строки плеера из runtime snapshot.
    private func makeArtworkRequest(
        track: PlayerTrack,
        trackId: UUID,
        snapshot: TrackRuntimeSnapshot?,
        shouldShowTags: Bool
    ) -> ArtworkRequest? {
        if track.isPurchasedITunesRuntimeTrack {
            return ArtworkRequest(
                trackId: trackId,
                artworkData: track.artworkData,
                purpose: .trackList,
                sourceIdentifier: .mediaLibrary(trackId: trackId)
            )
        }

        guard shouldShowTags else { return nil }
        return ArtworkRequest(
            trackId: trackId,
            snapshot: snapshot,
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
