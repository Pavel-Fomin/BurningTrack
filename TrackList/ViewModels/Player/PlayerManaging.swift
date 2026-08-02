//
//  PlayerManaging.swift
//  TrackList
//
//  Абстракция playback backend для PlayerViewModel.
//
//  Created by Pavel Fomin on 19.06.2026.
//

import Foundation
import MediaPlayer

/// Одноразово сообщает MainActor о подготовленном локальном файле, не передавая AVPlayer или внутреннее состояние менеджера.
typealias PlayerPreparedLocalFileHandler = @MainActor (PlayerPreparedLocalFile) -> Void

/// Описывает только playback API, который реально нужен PlayerViewModel.
protocol PlayerManaging: AnyObject {

    /// Запускает воспроизведение и сообщает о готовом локальном файле до ожидания длительности asset.
    func play(
        track: any TrackDisplayable,
        onPreparedLocalFile: @escaping PlayerPreparedLocalFileHandler
    ) async throws

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

    /// Полностью освобождает AVPlayerItem и доступ к файлу перед подтверждённой файловой операцией.
    func releaseCurrentTrackForFileOperation()

    /// Возвращает уже подготовленный плеером локальный URL текущего трека без повторного открытия bookmark-доступа.
    func preparedLocalFileURL(for trackId: UUID) -> URL?

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

    /// Настраивает единственный обработчик системной команды «Избранное».
    func configureFavoriteCommand(
        handler: @escaping @MainActor (Bool) -> MPRemoteCommandHandlerStatus
    )

    /// Синхронизирует доступность и подтверждённое состояние системной команды «Избранное».
    func updateFavoriteCommand(
        isEnabled: Bool,
        isActive: Bool
    )

    /// Удаляет обработчик системной команды «Избранное» при освобождении её владельца.
    func removeFavoriteCommandHandler()

    /// Синхронизирует системные команды перехода с опубликованной готовностью playback-контекста.
    func setTrackNavigationCommandsEnabled(
        isNextEnabled: Bool,
        isPreviousEnabled: Bool
    )

    /// Применяет полный snapshot Now Playing в системный Control Center.
    func applyNowPlaying(snapshot: NowPlayingSnapshot)

    /// Обновляет только время и состояние воспроизведения в Now Playing.
    func applyPlaybackTime(currentTime: TimeInterval, isPlaying: Bool)
}

extension PlayerManaging {
    /// Тестовые реализации могут ограничиться уже существующим освобождением security-scoped доступа.
    func releaseCurrentTrackForFileOperation() {
        pause()
        stopAccessingCurrentTrack()
    }

    /// Подмены PlayerManager в изолированных тестах не обязаны управлять системным Remote Command Center.
    func setTrackNavigationCommandsEnabled(
        isNextEnabled: Bool,
        isPreviousEnabled: Bool
    ) {}

    /// Подмены PlayerManager в изолированных тестах не обязаны регистрировать глобальную системную команду.
    func configureFavoriteCommand(
        handler: @escaping @MainActor (Bool) -> MPRemoteCommandHandlerStatus
    ) {}

    /// Подмены PlayerManager в изолированных тестах не обязаны хранить состояние глобальной системной команды.
    func updateFavoriteCommand(
        isEnabled: Bool,
        isActive: Bool
    ) {}

    /// Подмены PlayerManager в изолированных тестах не обязаны удалять глобальную системную команду.
    func removeFavoriteCommandHandler() {}
}

extension PlayerManager: PlayerManaging {}
