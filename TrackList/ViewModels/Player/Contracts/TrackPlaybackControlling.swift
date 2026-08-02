//
//  TrackPlaybackControlling.swift
//  TrackList
//
//  Контракт команд запуска воспроизведения трека.
//
//  Created by Pavel Fomin on 02.08.2026.
//

import Foundation

/// Выполняет минимальный набор playback-команд, нужный внешним feature.
/// Контракт намеренно не содержит очередь, переходы, seek, repeat, избранное, waveform и Now Playing.
/// Production-provider — PlayerViewModel, поэтому потребители не получают его конкретный тип.
@MainActor
protocol TrackPlaybackControlling: AnyObject {

    /// Переключает воспроизведение или паузу текущего трека.
    func togglePlayPause()

    /// Запускает выбранный трек в явном контексте и из указанного постоянного источника.
    func play(
        track: any TrackDisplayable,
        context: [any TrackDisplayable],
        source: PlaybackContextSource
    )
}
