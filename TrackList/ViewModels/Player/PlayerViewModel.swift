//
//  PlayerViewModel.swift
//  TrackList
//
//  ViewModel для управления воспроизведением:
//  - старт/пауза, перемотка, следующий/предыдущий
//  - наблюдение за прогрессом
//  - взаимодействие с Control Center и NowPlayingInfo
//
//  Работает с абстрактным протоколом TrackDisplayable и контекстами:
//  - PlayerTrack (плейлист плеера)
//  - Track (треклист)
//  - LibraryTrack (фонотека)
//  - PurchasedITunesPlayableTrack (купленные iTunes-треки)
//
//  Created by Pavel Fomin on 28.04.2025.
//


import Foundation
import AVFoundation
import UIKit
import QuartzCore

@MainActor
final class PlayerViewModel: ObservableObject {
    
    // MARK: - Публичные состояния
    
    @Published var currentTrackDisplayable: (any TrackDisplayable)?  /// Текущий воспроизводимый трек
    @Published var isPlaying: Bool = false                           /// Воспроизводится ли сейчас аудио
    @Published var currentTime: TimeInterval = 0.0                   /// Текущее время воспроизведения
    @Published var trackDuration: TimeInterval = 0.0                 /// Длительность текущего трека
    @Published var currentContext: PlaybackContext?                  /// Контекст воспроизведения
    @Published private(set) var snapshotsByTrackId: [UUID: TrackRuntimeSnapshot] = [:] /// Runtime snapshot треков по id

    /// Текущий режим читается из хранилища playback-контекста.
    var playbackMode: PlaybackMode {
        playbackContextStore.playbackMode
    }
    
    // MARK: - MiniPlayer State
    
    /// Единое явное состояние отображения мини-плеера.
    @Published private(set) var miniPlayerState: MiniPlayerState = .empty

    /// Статические данные сохраняются между обновлениями прогресса.
    private var miniPlayerStaticState: MiniPlayerStaticState?
    
    // MARK: - Throttling
    
    private var lastMiniPlayerTick: CFTimeInterval = 0
    private var lastNowPlayingTick: CFTimeInterval = 0
    
    // MARK: - Внутренние зависимости
    
    private let playerManager: any PlayerManaging
    private let playbackContextStore: PlayerPlaybackContextStore
    private let nowPlayingSnapshotBuilder: any NowPlayingSnapshotBuilding
    private let runtimeSnapshotController: PlayerRuntimeSnapshotController
    private let eventObserver: any PlayerEventObserving
    /// Показывает пользовательские ошибки без прямой зависимости от ToastManager.shared.
    private let toastPresenter: any ToastPresenting

    /// Конкретный PlayerManager нужен сценариям файловых операций,
    /// где используется проверка занятости трека.
    private let concretePlayerManager: PlayerManager?

    /// Отдаёт тот же PlayerManager для файловых операций вне playback-слоя.
    var fileOperationPlayerManager: PlayerManager {
        guard let concretePlayerManager else {
            preconditionFailure("Для файловых операций требуется PlayerManager")
        }

        return concretePlayerManager
    }

    // MARK: - Now Playing Snapshot
    
    /// Собирает snapshot для Control Center из текущего состояния.
    /// Источник метаданных — TrackRuntimeSnapshot или runtime-данные iTunes-адаптера.
    /// Artwork используется отдельного размера (~512 px).
    private func makeNowPlayingSnapshot(for track: any TrackDisplayable) -> NowPlayingSnapshot {
        nowPlayingSnapshotBuilder.makeSnapshot(
            track: track,
            runtimeSnapshot: runtimeSnapshotController.snapshot(for: track.trackId),
            artwork: runtimeSnapshotController.nowPlayingArtwork(for: track.trackId),
            currentTime: currentTime,
            fallbackDuration: trackDuration,
            isPlaying: isPlaying
        )
    }

    /// Публикует наружу актуальное зеркало runtime snapshot-ов контроллера.
    private func publishRuntimeSnapshots() {
        snapshotsByTrackId = runtimeSnapshotController.snapshotsByTrackId
    }
    
    // MARK: - Инициализация
    
    init(
        playerManager: any PlayerManaging = PlayerManager(),
        playbackContextStore: PlayerPlaybackContextStore? = nil,
        nowPlayingSnapshotBuilder: any NowPlayingSnapshotBuilding = NowPlayingSnapshotBuilder(),
        runtimeSnapshotController: PlayerRuntimeSnapshotController = PlayerRuntimeSnapshotController(),
        eventObserver: any PlayerEventObserving = NotificationPlayerEventObserver(),
        toastPresenter: (any ToastPresenting)? = nil
    ) {
        self.playerManager = playerManager
        // Store создаётся внутри main-actor и синхронно восстанавливает режим до первого контекста.
        self.playbackContextStore = playbackContextStore ?? PlayerPlaybackContextStore()
        self.nowPlayingSnapshotBuilder = nowPlayingSnapshotBuilder
        self.runtimeSnapshotController = runtimeSnapshotController
        self.eventObserver = eventObserver
        self.toastPresenter = toastPresenter ?? ToastManager.shared
        self.concretePlayerManager = playerManager as? PlayerManager

        // Обновление длительности трека
        eventObserver.onTrackDurationUpdated = { [weak self] duration in
            guard let self else { return }

            self.trackDuration = duration
            self.updateMiniPlayerProgressState()

            // Если есть текущий трек — пересобираем snapshot
            if let current = self.currentTrackDisplayable {
                self.playerManager.applyNowPlaying(
                    snapshot: self.makeNowPlayingSnapshot(for: current)
                )
            }
        }
        
        // Автопереход к следующему треку по завершении
        eventObserver.onTrackDidFinish = { [weak self] in
            self?.handleTrackDidFinish()
        }

        // Обновление runtime snapshot трека
        eventObserver.onTrackDidUpdate = { [weak self] event in
            self?.applyTrackUpdateEvent(event)
        }

        // Обновление runtime snapshot после изменения настроек приложения
        eventObserver.onSettingsChanged = { [weak self] in
            self?.reloadSnapshotsAfterSettingsChange()
        }
        
        // Настройка Remote Command Center
        playerManager.setupRemoteCommandCenter(
            onPlay: { [weak self] in
                DispatchQueue.main.async {
                    self?.togglePlayPause()
                }
            },
            onPause: { [weak self] in
                DispatchQueue.main.async {
                    self?.togglePlayPause()
                }
            },
            onNext: { [weak self] in
                DispatchQueue.main.async {
                    self?.playNextTrack()
                }
            },
            onPrevious: { [weak self] in
                DispatchQueue.main.async {
                    self?.playPreviousTrack()
                }
            }
        )
    }
    
    // MARK: - Snapshot
    
    // Реализация чтения runtime snapshot
    /// Возвращает runtime snapshot трека по его идентификатору.
    ///
    /// - Parameter trackId: Идентификатор трека
    /// - Returns: TrackRuntimeSnapshot или nil
    func snapshot(for trackId: UUID) -> TrackRuntimeSnapshot? {
        runtimeSnapshotController.snapshot(for: trackId)
    }
    
    /// Запрашивает runtime snapshot трека, если он ещё не загружен.
    ///
    /// - Parameter trackId: Идентификатор трека
    func requestSnapshotIfNeeded(for trackId: UUID) {
        Task {
            let changedTrackId = await runtimeSnapshotController.requestSnapshotIfNeeded(for: trackId)

            guard let changedTrackId else { return }

            publishRuntimeSnapshots()

            if let current = currentTrackDisplayable,
               current.trackId == changedTrackId {
                updateMiniPlayerStaticState(for: current)
                playerManager.applyNowPlaying(
                    snapshot: makeNowPlayingSnapshot(for: current)
                )
            }
        }
    }

    /// Запрашивает runtime snapshot только для треков, которые живут в bookmark-pipeline приложения.
    private func requestSnapshotIfNeeded(
        for track: any TrackDisplayable
    ) {
        guard !track.isPurchasedITunesRuntimeTrack else {
            // iTunes-трек уже содержит assetURL из MediaPlayer; snapshot-builder пошёл бы в BookmarkResolver без нужды.
            return
        }

        requestSnapshotIfNeeded(for: track.trackId)
    }

    /// Пересобирает runtime snapshot известных плееру треков после изменения настроек приложения.
    private func reloadSnapshotsAfterSettingsChange() {
        runtimeSnapshotController.clear()
        publishRuntimeSnapshots()

        let trackIds: Set<UUID>
        if currentTrackDisplayable?.isPurchasedITunesRuntimeTrack == true {
            // Для iTunes-трека нет записи в TrackRegistry, поэтому его не отправляем в BookmarkResolver.
            trackIds = []
        } else {
            trackIds = playbackContextStore.allTrackIds(
                currentTrack: currentTrackDisplayable
            )
        }

        for trackId in trackIds {
            requestSnapshotIfNeeded(for: trackId)
        }

        if let current = currentTrackDisplayable {
            updateMiniPlayerStaticState(for: current)
            playerManager.applyNowPlaying(
                snapshot: makeNowPlayingSnapshot(for: current)
            )
        }
    }
    
    /// Применяет единое событие обновления трека к состоянию плеера.
    ///
    /// - Parameter updateEvent: Событие обновления трека
    private func applyTrackUpdateEvent(_ updateEvent: TrackUpdateEvent) {
        let changedTrackId = runtimeSnapshotController.applyTrackUpdateEvent(updateEvent)

        publishRuntimeSnapshots()

        if let current = currentTrackDisplayable,
           current.trackId == changedTrackId {
            updateMiniPlayerStaticState(for: current)
            playerManager.applyNowPlaying(
                snapshot: makeNowPlayingSnapshot(for: current)
            )
        }
    }
    
    // MARK: - MiniPlayer State Updates
    
    /// Пересобирает статическое состояние мини-плеера из текущего трека и runtime snapshot.
    private func updateMiniPlayerStaticState(for track: any TrackDisplayable) {
        let snapshot = runtimeSnapshotController.snapshot(for: track.trackId)
        miniPlayerStaticState = MiniPlayerStateBuilder.buildStaticState(
            track: track,
            snapshot: snapshot
        )

        updateMiniPlayerState()
    }
    
    /// Пересобирает состояние мини-плеера из текущих публичных полей ViewModel.
    private func updateMiniPlayerProgressState() {
        updateMiniPlayerState()
    }

    /// Публикует состояние мини-плеера без изменения существующей playback-логики.
    private func updateMiniPlayerState() {
        guard currentTrackDisplayable != nil else {
            miniPlayerStaticState = nil
            miniPlayerState = .empty
            return
        }

        guard let staticState = miniPlayerStaticState else {
            miniPlayerState = .loading(staticState: nil)
            return
        }

        let progressState = MiniPlayerProgressState(
            isPlaying: isPlaying,
            currentTime: currentTime,
            duration: trackDuration
        )

        if isPlaying {
            miniPlayerState = .playing(
                staticState: staticState,
                progressState: progressState
            )
        } else {
            miniPlayerState = .paused(
                staticState: staticState,
                progressState: progressState
            )
        }
    }
    
    // MARK: - Воспроизведение трека

    /// Атомарно изменяет режимы воспроизведения текущего контекста.
    func setPlaybackMode(_ mode: PlaybackMode) {
        let normalizedMode = mode.normalized
        guard playbackMode != normalizedMode else { return }

        // Сообщаем SwiftUI об изменении вычисляемого состояния до изменения Store.
        objectWillChange.send()
        playbackContextStore.setPlaybackMode(
            normalizedMode,
            currentTrack: currentTrackDisplayable
        )
    }

    /// Переключает Shuffle и выключает Repeat при включении перемешивания.
    func toggleShuffle() {
        var mode = playbackMode
        if mode.isShuffleEnabled {
            mode.isShuffleEnabled = false
        } else {
            mode.isShuffleEnabled = true
            mode.repeatMode = .off
        }
        setPlaybackMode(mode)
    }

    /// Включает Repeat All и выключает остальные режимы.
    func toggleRepeatAll() {
        var mode = playbackMode
        if mode.repeatMode == .all {
            mode.repeatMode = .off
        } else {
            mode.isShuffleEnabled = false
            mode.repeatMode = .all
        }
        setPlaybackMode(mode)
    }

    /// Включает Repeat One и выключает остальные режимы.
    func toggleRepeatOne() {
        var mode = playbackMode
        if mode.repeatMode == .one {
            mode.repeatMode = .off
        } else {
            mode.isShuffleEnabled = false
            mode.repeatMode = .one
        }
        setPlaybackMode(mode)
    }
    
    /// Запуск воспроизведения трека в заданном контексте
    func play(track: any TrackDisplayable, context: [any TrackDisplayable] = []) {
        
        // Определяем контекст воспроизведения
        let contextType = PlaybackContext.detect(from: context)
        let isSameContext = playbackContextStore.isCurrentContext(context)
        let isSameTrack: Bool
        if let current = currentTrackDisplayable {
            isSameTrack = current.id == track.id &&
                type(of: current) == type(of: track) &&
                currentContext == contextType &&
                isSameContext
        } else {
            isSameTrack = false
        }

        currentContext = contextType

        // Обновляем контекст до проверки текущего трека, чтобы не потерять его позицию.
        _ = playbackContextStore.updateContext(
            currentTrack: track,
            context: context
        )

        // Если это тот же трек и тот же контекст — просто продолжить.
        if isSameTrack {
            playerManager.playCurrent()
            isPlaying = true
            updateMiniPlayerProgressState()
            return
        }
        
        // Новый трек: останавливаем доступ к старому
        playerManager.stopAccessingCurrentTrack()
        currentTrackDisplayable = track
        miniPlayerStaticState = nil
        currentTime = 0
        trackDuration = 0
        requestSnapshotIfNeeded(for: track)
        
        updateMiniPlayerStaticState(for: track)
        updateMiniPlayerProgressState()
        
        // Стартуем воспроизведение через PlayerManager
        Task { @MainActor in
            do {
                // Для iTunes-источника передаём в PlayerManager адаптер с assetURL,
                // а currentTrackDisplayable оставляем исходным для подсветки контекста.
                let playbackTrack = playbackTrack(for: track)
                try await playerManager.play(track: playbackTrack)
                isPlaying = true
                updateMiniPlayerProgressState()
                // Первичное заполнение Now Playing Info (duration ещё может быть 0)
                playerManager.applyNowPlaying(snapshot: makeNowPlayingSnapshot(for: track))
                // Наблюдаем прогресс воспроизведения
                playerManager.observeProgress { [weak self] time in
                    guard let self else { return }
                    self.currentTime = time
                    let now = CACurrentMediaTime()
                    // UI прогресс: ~20 Hz
                    if now - self.lastMiniPlayerTick >= 1.0 {
                        self.lastMiniPlayerTick = now
                        self.updateMiniPlayerProgressState()
                    }
                    // Now Playing: 1 Hz
                    if now - self.lastNowPlayingTick >= 1.0 {
                        self.lastNowPlayingTick = now
                        self.playerManager.applyPlaybackTime(currentTime: time, isPlaying: self.isPlaying)
                    }
                }
            } catch let appError as AppError {
                isPlaying = false
                updateMiniPlayerProgressState()
                toastPresenter.handle(appError)
            } catch {
                isPlaying = false
                updateMiniPlayerProgressState()
                toastPresenter.handle(.playbackFailed(title: track.title ?? track.fileName))
            }
        }
        
    }

    /// Возвращает трек, который должен попасть непосредственно в PlayerManager.
    private func playbackTrack(
        for track: any TrackDisplayable
    ) -> any TrackDisplayable {
        track.asPurchasedITunesPlayableTrack() ?? track
    }
    
    // MARK: - Управление воспроизведением

    func togglePlayPause() {
        if isPlaying {
            playerManager.pause()
        } else {
            guard currentTrackDisplayable != nil else { return }
            playerManager.playCurrent()
        }

        isPlaying.toggle()
        updateMiniPlayerProgressState()

        lastNowPlayingTick = 0
        playerManager.applyPlaybackTime(currentTime: currentTime, isPlaying: isPlaying)

        if let current = currentTrackDisplayable {
            playerManager.applyNowPlaying(snapshot: makeNowPlayingSnapshot(for: current))
        }
    }

    /// Обрабатывает завершение текущего трека с учётом режима повтора.
    private func handleTrackDidFinish() {
        if playbackMode.repeatMode == .one {
            restartCurrentTrack()
            return
        }

        guard startNextTrack() else {
            markPlaybackFinished()
            return
        }
    }

    /// Перезапускает текущий трек без повторной загрузки его модели.
    private func restartCurrentTrack() {
        guard currentTrackDisplayable != nil else { return }

        currentTime = 0
        isPlaying = true
        playerManager.restartCurrent()
        updateMiniPlayerProgressState()

        lastNowPlayingTick = 0
        playerManager.applyPlaybackTime(
            currentTime: currentTime,
            isPlaying: isPlaying
        )

        if let current = currentTrackDisplayable {
            playerManager.applyNowPlaying(
                snapshot: makeNowPlayingSnapshot(for: current)
            )
        }
    }

    /// Синхронизирует состояние ViewModel, если текущий контекст закончился без перехода.
    private func markPlaybackFinished() {
        isPlaying = false
        updateMiniPlayerProgressState()

        lastNowPlayingTick = 0
        playerManager.applyPlaybackTime(
            currentTime: currentTime,
            isPlaying: false
        )

        if let current = currentTrackDisplayable {
            playerManager.applyNowPlaying(
                snapshot: makeNowPlayingSnapshot(for: current)
            )
        }
    }

    func seek(to time: TimeInterval) {
        playerManager.seek(to: time)
        currentTime = time
        updateMiniPlayerProgressState()

        lastNowPlayingTick = 0
        playerManager.applyPlaybackTime(currentTime: time, isPlaying: isPlaying)

        if let current = currentTrackDisplayable {
            playerManager.applyNowPlaying(snapshot: makeNowPlayingSnapshot(for: current))
        }
    }
    
    
    // MARK: - Переход между треками
    
    /// Следующий трек в текущем контексте
    func playNextTrack() {
        _ = startNextTrack()
    }

    /// Запускает следующий трек и сообщает, был ли найден переход.
    @discardableResult
    private func startNextTrack() -> Bool {
        guard let current = currentTrackDisplayable,
              let next = playbackContextStore.nextTrack(after: current) else {
            return false
        }

        if next.track.id == current.id,
           type(of: next.track) == type(of: current) {
            restartCurrentTrack()
        } else {
            play(track: next.track, context: next.context)
        }
        return true
    }
    
    /// Предыдущий трек в текущем контексте
    func playPreviousTrack() {
        guard let current = currentTrackDisplayable else { return }
        
        if currentTime > 3 {
            seek(to: 0)
            return
        }

        guard let previous = playbackContextStore.previousTrack(before: current) else { return }

        if previous.track.id == current.id,
           type(of: previous.track) == type(of: current) {
            restartCurrentTrack()
            return
        }

        play(track: previous.track, context: previous.context)
    }
    
    
    // MARK: - Проверка "текущего" трека
    
    func isCurrent(_ track: any TrackDisplayable, in context: PlaybackContext) -> Bool {
        guard let current = currentTrackDisplayable,
              let currentCtx = currentContext else { return false }
        
        return current.id == track.id && currentCtx == context
    }
    
    
    
    // MARK: - Деинициализация
    
    deinit {
        playerManager.removeTimeObserver()
    }
}
