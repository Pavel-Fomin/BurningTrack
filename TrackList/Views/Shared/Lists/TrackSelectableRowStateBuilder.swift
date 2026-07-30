//
//  TrackSelectableRowStateBuilder.swift
//  TrackList
//
//  Builder presentation-состояния строк выбора трека.
//
//  Created by Pavel Fomin on 30.07.2026.
//

import Foundation

/// Собирает состояние строки выбора из локального трека, runtime snapshot и published-снимка «Избранного».
struct TrackSelectableRowStateBuilder {

    /// Фабрика централизует правила выбора единственного бейджа обложки.
    private let artworkBadgeStateFactory: any TrackArtworkBadgeStateBuilding

    /// Создаёт builder с общей фабрикой состояния бейджа.
    init(
        artworkBadgeStateFactory: any TrackArtworkBadgeStateBuilding = TrackArtworkBadgeStateFactory()
    ) {
        self.artworkBadgeStateFactory = artworkBadgeStateFactory
    }

    /// Собирает готовое состояние одной локальной строки выбора.
    func build(
        track: LibraryTrack,
        snapshot: TrackRuntimeSnapshot?,
        favoriteTrackIds: Set<UUID>,
        isSelected: Bool,
        showsFileFormat: Bool
    ) -> TrackSelectableRowState {
        TrackSelectableRowState(
            track: track,
            artworkRequest: ArtworkRequest(
                trackId: track.trackId,
                snapshot: snapshot,
                purpose: .trackList
            ),
            artworkBadgeState: artworkBadgeStateFactory.makeState(
                source: .library,
                isFavorite: favoriteTrackIds.contains(track.trackId)
            ),
            title: snapshot?.title ?? track.title,
            artist: snapshot?.artist ?? track.artist ?? "",
            duration: snapshot?.duration ?? track.duration,
            isSelected: isSelected,
            showsFileFormat: showsFileFormat
        )
    }
}
