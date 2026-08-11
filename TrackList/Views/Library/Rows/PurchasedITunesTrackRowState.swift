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
struct PurchasedITunesTrackRowState: Equatable {
    let track: PurchasedITunesPlayableTrack
    let artworkRequest: ArtworkRequest
    let title: String?
    let artist: String
    let duration: Double
    /// Текущее подтверждённое состояние «Избранного» для меню строки.
    let isFavorite: Bool
    let artworkBadgeState: TrackArtworkBadgeState
    /// Строка представляет текущий iTunes-трек в активном playback-контексте.
    let isCurrent: Bool
    /// Текущая строка находится в состоянии воспроизведения.
    let isPlaying: Bool
}
