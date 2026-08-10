//
//  MiniPlayerScreenState.swift
//  TrackList
//
//  Готовое состояние представления MiniPlayer.
//
//  Created by Pavel Fomin on 10.08.2026.
//

import Foundation

/// Содержит только данные, необходимые основной разметке MiniPlayer, без playback- и domain-зависимостей.
struct MiniPlayerScreenState: Equatable {
    /// Лёгкий запрос artwork текущего трека или fallback-состояния.
    let artworkRequest: ArtworkRequest?
    /// Готовый локализованный заголовок MiniPlayer.
    let title: String
    /// Готовая подпись исполнителя с presentation fallback.
    let artist: String
    /// Текущее время отображения прогресса.
    let currentTime: TimeInterval
    /// Длительность текущего трека.
    let duration: TimeInterval
    /// Признак активного воспроизведения для header artwork и доступности.
    let isPlaying: Bool
    /// Показывает наличие текущего трека для playback-управления.
    let isPlaybackEnabled: Bool
    /// Подтверждённое состояние «Избранного» текущего трека.
    let isFavorite: Bool
    /// Разрешает действие «Избранное» только при наличии конкретного трека.
    let isFavoriteEnabled: Bool
    /// Производное состояние waveform, которое передаётся специализированному компоненту.
    let waveformState: PlayerWaveformState
    /// Показывает доступность общего действия «Показать в фонотеке».
    let canShowCurrentTrackInLibrary: Bool
    /// Готовый флаг активного Shuffle.
    let isShuffleEnabled: Bool
    /// Готовый флаг активного Repeat All.
    let isRepeatAllEnabled: Bool
    /// Готовый флаг активного Repeat One.
    let isRepeatOneEnabled: Bool
    /// Начальное сохранённое раскрытие, применяемое локальным @State при создании View.
    let initialIsExpanded: Bool
}
