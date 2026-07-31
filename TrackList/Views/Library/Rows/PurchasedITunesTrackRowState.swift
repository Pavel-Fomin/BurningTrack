//
//  PurchasedITunesTrackRowState.swift
//  TrackList
//
//  Готовое presentation-состояние строки купленного iTunes-трека.
//
//  Created by Pavel Fomin on 30.07.2026.
//

import Foundation

/// Хранит подготовленные данные строки iTunes без действий и зависимостей от ViewModel.
struct PurchasedITunesTrackRowState {
    let track: PurchasedITunesPlayableTrack
    let artworkRequest: ArtworkRequest
    let title: String?
    let artist: String
    let duration: Double
    /// Текущее подтверждённое состояние «Избранного» для меню строки.
    let isFavorite: Bool
    let artworkBadgeState: TrackArtworkBadgeState
}
