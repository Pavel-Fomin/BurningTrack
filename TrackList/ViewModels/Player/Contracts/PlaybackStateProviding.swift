//
//  PlaybackStateProviding.swift
//  TrackList
//
//  Контракты состояния воспроизведения для внешних feature.
//
//  Created by Pavel Fomin on 02.08.2026.
//

import Combine
import Foundation

/// Неизменяемый снимок состояния воспроизведения для presentation-слоя.
/// Хранит только данные текущей строки и контекста, без команд, очереди и runtime metadata.
struct PlaybackStateSnapshot: Equatable {

    /// Идентификатор отображаемого элемента: строки очереди или треклиста.
    let currentDisplayableId: UUID?
    /// Идентификатор физического трека, если он доступен у текущего элемента.
    let currentTrackId: UUID?
    /// Обобщённый тип текущего контекста, необходимый существующим state builder-ам строк.
    let currentContext: PlaybackContext?
    /// Постоянный источник текущего контекста без раскрытия внутреннего PlayerViewModel.
    let currentContextSource: PlaybackContextSource?
    /// Признак активного воспроизведения.
    let isPlaying: Bool
}

/// Предоставляет реактивное состояние воспроизведения внешним feature.
/// Контракт не содержит playback-команд, очередь, избранное, waveform, Now Playing и настройки.
/// Production-provider — PlayerViewModel; потребители не получают его конкретный тип.
@MainActor
protocol PlaybackStateProviding: AnyObject {

    /// Актуальный снимок состояния без необходимости подписки.
    var playbackState: PlaybackStateSnapshot { get }
    /// Идентификатор текущего отображаемого элемента.
    var currentDisplayableId: UUID? { get }
    /// Идентификатор физического текущего трека.
    var currentTrackId: UUID? { get }
    /// Обобщённый тип текущего playback-контекста.
    var currentContext: PlaybackContext? { get }
    /// Постоянный источник текущего playback-контекста.
    var currentContextSource: PlaybackContextSource? { get }
    /// Признак активного воспроизведения.
    var isPlaying: Bool { get }
    /// Единый поток изменений полного playback-состояния.
    var playbackStatePublisher: AnyPublisher<PlaybackStateSnapshot, Never> { get }
}
