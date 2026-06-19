//
//  PlaybackStateProviding.swift
//  TrackList
//
//  Created by Pavel Fomin on 19.06.2026.
//

import Combine

/// Предоставляет playback-состояние для detail-flow одного треклиста.
@MainActor
protocol PlaybackStateProviding: AnyObject {

    /// Текущее playback-состояние без подписки.
    var playbackState: PlaybackState { get }

    /// Поток изменений playback-состояния.
    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> { get }
}
