//
//  PurchasedITunesPresenter.swift
//  TrackList
//
//  Преобразует данные медиатеки и runtime-снимки в состояние экрана iTunes.
//
//  Created by Pavel Fomin on 11.08.2026.
//

import Foundation

/// Формирует готовые строки и состояние экрана без обращения к MediaPlayer, singleton или SwiftUI.
struct PurchasedITunesPresenter {

    /// Единая фабрика определяет приоритет source- и favorite-бейджей.
    private let artworkBadgeStateFactory: any TrackArtworkBadgeStateBuilding

    /// Получает чистую фабрику presentation-бейджа из feature factory.
    init(
        artworkBadgeStateFactory: any TrackArtworkBadgeStateBuilding
    ) {
        self.artworkBadgeStateFactory = artworkBadgeStateFactory
    }

    /// Собирает единый снимок из данных загрузки и подтверждённых runtime-состояний.
    func present(
        content: PurchasedITunesMusicContent,
        sortMode: PurchasedITunesTrackSortMode,
        favoriteTrackIds: Set<UUID>,
        playbackState: PlaybackStateSnapshot
    ) -> PurchasedITunesScreenState {
        switch content {
        case .idle, .loading:
            return PurchasedITunesScreenState(
                content: .loading,
                sortMode: sortMode,
                canExport: false,
                tracks: []
            )

        case .denied:
            return PurchasedITunesScreenState(
                content: .denied,
                sortMode: sortMode,
                canExport: false,
                tracks: []
            )

        case .empty:
            return PurchasedITunesScreenState(
                content: .empty,
                sortMode: sortMode,
                canExport: false,
                tracks: []
            )

        case .loaded(let sourceTracks):
            let tracks = sourceTracks.map(PurchasedITunesPlayableTrack.init(track:))
            let rows = tracks.map {
                makeRowState(
                    track: $0,
                    favoriteTrackIds: favoriteTrackIds,
                    playbackState: playbackState
                )
            }

            return PurchasedITunesScreenState(
                content: .loaded(rows),
                sortMode: sortMode,
                canExport: tracks.isEmpty == false,
                tracks: tracks
            )
        }
    }

    /// Подготавливает одну строку, чтобы leaf View не интерпретировал favorite- и playback-состояния.
    private func makeRowState(
        track: PurchasedITunesPlayableTrack,
        favoriteTrackIds: Set<UUID>,
        playbackState: PlaybackStateSnapshot
    ) -> PurchasedITunesTrackRowState {
        let isFavorite = favoriteTrackIds.contains(track.trackId)
        let isCurrent = playbackState.currentDisplayableId == track.id
            && playbackState.currentContext == .purchasedITunes

        return PurchasedITunesTrackRowState(
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
            isFavorite: isFavorite,
            artworkBadgeState: artworkBadgeStateFactory.makeState(
                source: .purchasedITunes,
                isFavorite: isFavorite
            ),
            isCurrent: isCurrent,
            isPlaying: isCurrent && playbackState.isPlaying
        )
    }
}
