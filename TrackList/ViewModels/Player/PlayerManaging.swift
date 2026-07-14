//
//  PlayerManaging.swift
//  TrackList
//
//  Абстракция playback backend для PlayerViewModel.
//
//  Created by Pavel Fomin on 19.06.2026.
//

import Foundation

/// Описывает только playback API, который реально нужен PlayerViewModel.
protocol PlayerManaging: AnyObject {

    /// Запускает воспроизведение переданного трека.
    func play(track: any TrackDisplayable) async throws

    /// Продолжает воспроизведение текущего AVPlayerItem.
    func playCurrent()

    /// Перезапускает текущий AVPlayerItem с начала.
    func restartCurrent()

    /// Ставит текущее воспроизведение на паузу.
    func pause()

    /// Перематывает текущий трек на указанное время.
    func seek(to time: TimeInterval)

    /// Освобождает security-scoped доступ к текущему треку.
    func stopAccessingCurrentTrack()

    /// Подписывает внешний слой на обновления прогресса воспроизведения.
    func observeProgress(update: @escaping (TimeInterval) -> Void)

    /// Удаляет time observer прогресса воспроизведения.
    func removeTimeObserver()

    /// Настраивает обработчики системного Remote Command Center.
    func setupRemoteCommandCenter(
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onPrevious: @escaping () -> Void
    )

    /// Применяет полный snapshot Now Playing в системный Control Center.
    func applyNowPlaying(snapshot: NowPlayingSnapshot)

    /// Обновляет только время и состояние воспроизведения в Now Playing.
    func applyPlaybackTime(currentTime: TimeInterval, isPlaying: Bool)
}

extension PlayerManager: PlayerManaging {}
