//
//  TrackListPlaybackManaging.swift
//  TrackList
//
//  Created by Pavel Fomin on 18.06.2026.
//

import Foundation

/// Управляет воспроизведением для detail-flow одного треклиста.
@MainActor
protocol TrackListPlaybackManaging {
    /// Текущий трек плеера.
    var currentTrackDisplayable: (any TrackDisplayable)? { get }

    /// Запущено ли воспроизведение.
    var isPlaying: Bool { get }

    /// Переключает воспроизведение / паузу.
    func togglePlayPause()

    /// Запускает трек в контексте треклиста.
    func play(
        track: Track,
        context: [Track]
    )
}
