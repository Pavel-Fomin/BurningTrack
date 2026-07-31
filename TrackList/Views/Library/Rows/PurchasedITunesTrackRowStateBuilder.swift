//
//  PurchasedITunesTrackRowStateBuilder.swift
//  TrackList
//
//  Builder presentation-состояния строки купленного iTunes-трека.
//
//  Created by Pavel Fomin on 30.07.2026.
//

import Foundation

/// Собирает данные строки iTunes до передачи в контейнер и общий TrackRowView.
struct PurchasedITunesTrackRowStateBuilder {

    /// Фабрика изолирует правила выбора бейджа от строки и её контейнера.
    private let artworkBadgeStateFactory: any TrackArtworkBadgeStateBuilding

    /// Создаёт builder с общей фабрикой состояния бейджа.
    init(
        artworkBadgeStateFactory: any TrackArtworkBadgeStateBuilding = TrackArtworkBadgeStateFactory()
    ) {
        self.artworkBadgeStateFactory = artworkBadgeStateFactory
    }

    /// Формирует готовые данные отображения для одного трека iTunes.
    func build(
        track: PurchasedITunesPlayableTrack,
        favoriteTrackIds: Set<UUID>
    ) -> PurchasedITunesTrackRowState {
        PurchasedITunesTrackRowState(
            track: track,
            artworkRequest: ArtworkRequest(
                trackId: track.trackId,
                artworkData: track.artworkData,
                purpose: .trackList,
                sourceIdentifier: .mediaLibrary(trackId: track.trackId)
            ),
            title: track.title,
            artist: track.artist ?? String(localized: "Unknown Artist"),
            duration: track.duration,
            isFavorite: favoriteTrackIds.contains(track.trackId),
            artworkBadgeState: artworkBadgeStateFactory.makeState(
                source: .purchasedITunes,
                isFavorite: favoriteTrackIds.contains(track.trackId)
            )
        )
    }
}
