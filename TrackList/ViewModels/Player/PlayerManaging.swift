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
typealias PlayerPreparedLocalFileHandler = @MainActor @Sendable (PlayerPreparedLocalFile) -> Void

/// Отличает конкретный запуск playback от business identity трека, который может повторно выбираться пользователем.
struct PlaybackRequestID: Hashable, Sendable {

    /// Значение создаётся единственным владельцем lifecycle — PlayerManager.
    let rawValue: UUID

    /// Формирует новую identity только для начала нового пользовательского playback-запроса.
    init() {
        rawValue = UUID()
    }
}

/// Явно сообщает ViewModel, что поздний запрос не изменил runtime-состояние актуального playback.
enum PlaybackStartResult: Equatable, Sendable {
    /// Запрос подготовил и установил свой AVPlayerItem.
    case started
    /// Запрос устарел после suspension boundary и освободил только свои временные ресурсы.
    case superseded
}

/// Описывает только playback API, который реально нужен PlayerViewModel.
@MainActor
protocol PlayerManaging: AnyObject {

    /// Регистрирует новое пользовательское намерение и инвалидирует все незавершённые более старые запуски.
    func beginPlaybackRequest() -> PlaybackRequestID

    /// Возвращает актуальность identity, которой владеет фактический AVPlayer lifecycle.
    func isCurrentPlaybackRequest(_ requestID: PlaybackRequestID) -> Bool

    /// Инвалидирует request только если он всё ещё принадлежит текущему lifecycle.
    func invalidatePlaybackRequest(_ requestID: PlaybackRequestID)

    /// Запускает воспроизведение для уже зарегистрированного request и сообщает о supersession без ложной ошибки.
    func play(
        requestID: PlaybackRequestID,
        track: any TrackDisplayable,
        onPreparedLocalFile: @escaping PlayerPreparedLocalFileHandler
    ) async throws -> PlaybackStartResult

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
    func observeProgress(update: @escaping @MainActor @Sendable (TimeInterval) -> Void)

    /// Удаляет time observer прогресса воспроизведения.
    func removeTimeObserver()

    /// Настраивает обработчики системного Remote Command Center.
    func setupRemoteCommandCenter(
        onPlay: @escaping @MainActor @Sendable () -> Void,
        onPause: @escaping @MainActor @Sendable () -> Void,
        onNext: @escaping @MainActor @Sendable () -> Void,
        onPrevious: @escaping @MainActor @Sendable () -> Void
    )

    /// Настраивает единственный обработчик системной команды «Избранное».
    func configureFavoriteCommand(
        handler: @escaping @MainActor @Sendable (Bool) -> MPRemoteCommandHandlerStatus
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
    /// Изолированные старые doubles не владеют AVPlayer lifecycle и считают собственный запрос актуальным.
    func beginPlaybackRequest() -> PlaybackRequestID {
        PlaybackRequestID()
    }

    /// Default нужен только простым doubles, которые не моделируют конкурентные запросы.
    func isCurrentPlaybackRequest(_: PlaybackRequestID) -> Bool {
        true
    }

    /// Простые doubles не удерживают отдельный request-state.
    func invalidatePlaybackRequest(_: PlaybackRequestID) {}

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
        handler: @escaping @MainActor @Sendable (Bool) -> MPRemoteCommandHandlerStatus
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
