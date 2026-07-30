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
import Combine

@MainActor
final class PlayerViewModel: ObservableObject {
    
    // MARK: - Публичные состояния
    
    @Published var currentTrackDisplayable: (any TrackDisplayable)? { /// Текущий воспроизводимый трек
        didSet {
            guard oldValue?.trackId != currentTrackDisplayable?.trackId else {
                return
            }

            refreshCurrentTrackFavoriteState()
        }
    }
    @Published var isPlaying: Bool = false                           /// Воспроизводится ли сейчас аудио
    @Published var currentTime: TimeInterval = 0.0                   /// Текущее время воспроизведения
    @Published var trackDuration: TimeInterval = 0.0                 /// Длительность текущего трека
    @Published var currentContext: PlaybackContext?                  /// Контекст воспроизведения
    /// Показывает, что для текущего трека получен достоверный playback-массив, а не только ранняя display-модель.
    @Published private(set) var isPlaybackContextReady = false
    /// Разрешает переход к предыдущему треку только после проверки готового playback-контекста.
    @Published private(set) var canPlayPreviousTrack = false
    /// Разрешает переход к следующему треку только после проверки готового playback-контекста.
    @Published private(set) var canPlayNextTrack = false
    @Published private(set) var snapshotsByTrackId: [UUID: TrackRuntimeSnapshot] = [:] /// Runtime snapshot треков по id
    /// Показывает состояние «Избранного» только для текущего трека плеера.
    @Published private(set) var isCurrentTrackFavorite: Bool = false {
        didSet {
            updateFavoriteCommandState()
        }
    }

    /// Текущий режим читается из хранилища playback-контекста.
    var playbackMode: PlaybackMode {
        playbackContextStore.playbackMode
    }
    
    // MARK: - MiniPlayer State
    
    /// Единое явное состояние отображения мини-плеера.
    /// До чтения player_state отсутствие трека ещё не подтверждено, поэтому UI начинает с loading.
    @Published private(set) var miniPlayerState: MiniPlayerState = .loading(staticState: nil)

    /// Статические данные сохраняются между обновлениями прогресса.
    private var miniPlayerStaticState: MiniPlayerStaticState?

    /// Производное состояние waveform хранится отдельно от часто обновляемого состояния прогресса.
    @Published private(set) var waveformState: PlayerWaveformState = .unavailable
    /// Задача существует только для текущего трека и отменяется до запуска следующей генерации.
    private var waveformTask: Task<Void, Never>?
    
    // MARK: - Throttling

    private var lastNowPlayingTick: CFTimeInterval = 0
    
    // MARK: - Внутренние зависимости
    
    private let playerManager: any PlayerManaging
    private let playbackContextStore: PlayerPlaybackContextStore
    private let nowPlayingSnapshotBuilder: any NowPlayingSnapshotBuilding
    private let runtimeSnapshotController: PlayerRuntimeSnapshotController
    private let eventObserver: any PlayerEventObserving
    /// Выполняет доменные операции «Избранного», не раскрывая ViewModel работу с треклистами.
    private let favoritesService: any FavoritesServicing
    /// Передаёт точечные изменения «Избранного» для уже выбранного трека.
    private let favoritesEvents: any FavoritesEventsObserving
    /// Показывает пользовательские ошибки без прямой зависимости от ToastManager.shared.
    private let toastPresenter: any ToastPresenting
    /// Изолирует постоянное состояние выбранного трека от playback- и UI-логики.
    private let statePersistence: (any PlayerStatePersisting)?
    /// Очередь используется для восстановления PlayerTrack и проверки удаления текущего элемента.
    private let playlistManager: PlaylistManager
    /// Загружает актуальные списки фонотеки без переноса SQLite-логики в PlayerViewModel.
    private let libraryContextLoader: any LibraryPlaybackContextLoading
    /// Быстро получает один display-трек из SQLite-реестра без открытия файла и bookmark-доступа.
    private let fastLibraryTrackProvider: any FastLibraryTrackProviding
    /// Позволяет отложить полный контекст до готовности фонотеки и подменить состояние в изолированных тестах.
    private let isLibraryAccessRestored: @MainActor () -> Bool
    /// Слой генерации скрывает AVAssetReader и файловый кэш от ViewModel.
    private let waveformGenerator: any WaveformGenerating
    /// Показывает, что текущий трек восстановлен для интерфейса, но ещё не загружен в PlayerManager.
    private var isCurrentTrackPreparedForPlayback = false
    /// Не допускает параллельную подготовку одного ранне восстановленного трека по быстрым повторным нажатиям Play.
    private var isPreparingCurrentTrackForPlayback = false
    /// Источник текущего playback-контекста нужен для сохранения его при переходе Next/Previous.
    private var currentPlaybackContextSource: PlaybackContextSource = .playerQueue
    /// Наблюдатель нужен для повторной попытки восстановления локального трека после открытия bookmark-доступа.
    private var libraryAccessRestoredObserver: NSObjectProtocol?
    /// Хранит Combine-подписки PlayerViewModel на протяжении её жизненного цикла.
    private var cancellables = Set<AnyCancellable>()

    /// Хранит только незавершённое стартовое восстановление, не дублируя данные в SQLite или отдельном кэше.
    private struct PendingLastTrackRestoration {
        /// Идентификатор отделяет устаревшие async-результаты от текущего выбора пользователя.
        let identifier: UUID
        /// Стабильный id сохранённого трека для быстрой и полной проверок.
        let trackId: UUID
        /// Исходный контекст нужен позднему восстановлению порядка Next/Previous.
        let source: PlaybackContextSource
        /// Queue item сохраняет точную позицию среди повторных вхождений одного trackId.
        let queueItemId: UUID?
        /// Сохранённая длительность применяется только как UI fallback до загрузки runtime-данных.
        let duration: TimeInterval?
        /// Не допускает параллельные чтения одного трека из реестра.
        var isFastLookupInFlight = false
        /// Не допускает параллельные fallback-проверки очереди через bookmark-путь.
        var isFallbackTrackRestoreInFlight = false
        /// Не допускает параллельные загрузки полного контекста после libraryAccessRestored.
        var isContextRestoreInFlight = false
    }

    /// Ненулевое значение означает, что отображение или полный контекст стартового трека ещё восстанавливаются.
    private var pendingLastTrackRestoration: PendingLastTrackRestoration?

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

    /// Публикует готовность playback-контекста и синхронно пересчитывает доступность всех переходов.
    private func setPlaybackContextReady(_ isReady: Bool) {
        isPlaybackContextReady = isReady
        updateTrackNavigationAvailability()
    }

    /// Вычисляет доступность переходов из единственного playback-порядка и обновляет системные команды.
    private func updateTrackNavigationAvailability() {
        guard isPlaybackContextReady,
              let currentTrack = currentTrackDisplayable
        else {
            canPlayPreviousTrack = false
            canPlayNextTrack = false
            playerManager.setTrackNavigationCommandsEnabled(
                isNextEnabled: false,
                isPreviousEnabled: false
            )
            return
        }

        canPlayPreviousTrack = playbackContextStore.canMoveToPrevious(
            before: currentTrack
        )
        canPlayNextTrack = playbackContextStore.canMoveToNext(
            after: currentTrack
        )
        playerManager.setTrackNavigationCommandsEnabled(
            isNextEnabled: canPlayNextTrack,
            isPreviousEnabled: canPlayPreviousTrack
        )
    }
    
    // MARK: - Инициализация
    
    init(
        playerManager: any PlayerManaging = PlayerManager(),
        playbackContextStore: PlayerPlaybackContextStore? = nil,
        nowPlayingSnapshotBuilder: any NowPlayingSnapshotBuilding = NowPlayingSnapshotBuilder(),
        runtimeSnapshotController: PlayerRuntimeSnapshotController = PlayerRuntimeSnapshotController(),
        eventObserver: any PlayerEventObserving = NotificationPlayerEventObserver(),
        toastPresenter: (any ToastPresenting)? = nil,
        statePersistence: (any PlayerStatePersisting)? = nil,
        playlistManager: PlaylistManager? = nil,
        libraryContextLoader: (any LibraryPlaybackContextLoading)? = nil,
        fastLibraryTrackProvider: (any FastLibraryTrackProviding)? = nil,
        isLibraryAccessRestored: (@MainActor () -> Bool)? = nil,
        waveformGenerator: (any WaveformGenerating)? = nil,
        favoritesService: any FavoritesServicing,
        favoritesEvents: any FavoritesEventsObserving
    ) {
        let resolvedPlaylistManager = playlistManager ?? PlaylistManager.shared

        self.playerManager = playerManager
        // Store создаётся внутри main-actor и синхронно восстанавливает режим до первого контекста.
        self.playbackContextStore = playbackContextStore ?? PlayerPlaybackContextStore()
        self.nowPlayingSnapshotBuilder = nowPlayingSnapshotBuilder
        self.runtimeSnapshotController = runtimeSnapshotController
        self.eventObserver = eventObserver
        self.favoritesService = favoritesService
        self.favoritesEvents = favoritesEvents
        self.toastPresenter = toastPresenter ?? ToastManager.shared
        self.statePersistence = statePersistence ?? (try? PlayerStatePersistence())
        self.playlistManager = resolvedPlaylistManager
        self.libraryContextLoader = libraryContextLoader ?? LibraryPlaybackContextLoader()
        self.fastLibraryTrackProvider = fastLibraryTrackProvider ?? FastLibraryTracksProvider()
        // Singleton читается внутри MainActor-init, а тесты передают изолированный источник готовности.
        self.isLibraryAccessRestored = isLibraryAccessRestored ?? {
            MusicLibraryManager.shared.isAccessRestored
        }
        self.waveformGenerator = waveformGenerator ?? WaveformCachedGenerator(
            generator: WaveformGenerator(),
            cache: WaveformFileCache()
        )
        self.concretePlayerManager = playerManager as? PlayerManager

        if self.statePersistence == nil {
            PersistentLogger.log("PlayerViewModel: не удалось создать хранилище состояния плеера")
        }

        // Очередь уведомляет ViewModel только после успешной синхронизации с SQLite.
        resolvedPlaylistManager.onTracksChanged = { [weak self] tracks in
            self?.handlePlaylistChanged(tracks)
        }

        libraryAccessRestoredObserver = NotificationCenter.default.addObserver(
            forName: .libraryAccessRestored,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.resumeLastTrackRestorationAfterLibraryAccess()
            }
        }

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
        playerManager.configureFavoriteCommand { [weak self] isFavorite in
            guard let self else {
                return .commandFailed
            }

            return self.setCurrentTrackFavorite(isFavorite)
                ? .success
                : .commandFailed
        }
        updateFavoriteCommandState()
        updateTrackNavigationAvailability()

        // Стартовое восстановление готовит только состояние мини-плеера и не запускает AVPlayer.
        observeFavoritesChanges()
        startLastTrackRestoration()
    }

    // MARK: - Состояние выбранного трека

    /// Синхронно получает состояние «Избранного» при фактической смене текущего trackId.
    private func refreshCurrentTrackFavoriteState() {
        guard let currentTrack = currentTrackDisplayable else {
            isCurrentTrackFavorite = false
            return
        }

        do {
            isCurrentTrackFavorite = try favoritesService.isFavorite(
                trackId: currentTrack.trackId
            )
        } catch {
            // Ошибка чтения не должна оставлять состояние предыдущего трека в интерфейсной модели.
            isCurrentTrackFavorite = false
            PersistentLogger.log(
                "PlayerViewModel: ошибка проверки избранного trackId=\(currentTrack.trackId) error=\(error)"
            )
        }
    }

    /// Синхронизирует системную команду с наличием текущего трека и подтверждённым состоянием «Избранного».
    private func updateFavoriteCommandState() {
        let isEnabled = currentTrackDisplayable != nil
        playerManager.updateFavoriteCommand(
            isEnabled: isEnabled,
            isActive: isEnabled && isCurrentTrackFavorite
        )
    }

    /// Подписывается на единый поток точечных изменений «Избранного» только один раз при создании ViewModel.
    private func observeFavoritesChanges() {
        favoritesEvents.events
            .sink { [weak self] event in
                guard let self,
                      event.trackId == self.currentTrackDisplayable?.trackId
                else {
                    return
                }

                self.isCurrentTrackFavorite = event.isFavorite
            }
            .store(in: &cancellables)
    }

    /// Сохраняет новый текущий трек и источник контекста после фактической смены selection.
    private func persistCurrentTrack(
        _ track: any TrackDisplayable,
        source: PlaybackContextSource
    ) {
        guard let statePersistence else { return }

        let queueItemId = (track as? PlayerTrack)?.queueItemId
        PersistentLogger.log(
            "Player state save begin: trackId=\(track.trackId) " +
            "source=\(playbackSourceLogDescription(source))"
        )

        do {
            try statePersistence.saveCurrentTrack(
                trackId: track.trackId,
                queueItemId: queueItemId,
                duration: track.duration,
                playbackMode: playbackMode,
                contextSource: source
            )
            PersistentLogger.log(
                "Player state save success: trackId=\(track.trackId) " +
                "source=\(playbackSourceLogDescription(source))"
            )
        } catch {
            // Ошибка постоянного состояния не должна прерывать запуск воспроизведения.
            PersistentLogger.log("PlayerViewModel: ошибка сохранения состояния плеера: \(error)")
        }
    }

    /// Начинает восстановление сохранённого трека и разделяет быстрый UI-путь от полного playback-контекста.
    private func startLastTrackRestoration() {
        guard currentTrackDisplayable == nil,
              pendingLastTrackRestoration == nil
        else {
            return
        }

        // До загрузки полного массива сохранённый трек не даёт права навигации по неизвестному контексту.
        setPlaybackContextReady(false)

        guard let statePersistence else {
            // Без доступного состояния невозможно отличить прошлый выбор от пустого запуска.
            PersistentLogger.log("Player restore skipped: состояние плеера недоступно")
            publishConfirmedEmptyMiniPlayerState()
            return
        }

        publishLastTrackRestorationLoading()
        PersistentLogger.log("Player restore started")

        let state: PlayerStateDatabaseModel?
        do {
            state = try statePersistence.loadState()
        } catch {
            PersistentLogger.log(
                "PlayerViewModel: невалидное или недоступное состояние плеера: \(error)"
            )
            // Повреждённое состояние не должно оставлять старую запись для повторной ошибки на каждом запуске.
            clearPersistedState(reason: stateLoadClearReason(for: error))
            publishConfirmedEmptyMiniPlayerState()
            return
        }

        guard let state else {
            PersistentLogger.log("Player state load: empty")
            publishConfirmedEmptyMiniPlayerState()
            return
        }

        PersistentLogger.log(
            "Player state load: \(playerStateLogDescription(state))"
        )

        guard let trackId = state.currentTrackId else {
            clearPersistedState(reason: "отсутствует currentTrackId в сохранённом состоянии плеера")
            publishConfirmedEmptyMiniPlayerState()
            return
        }

        guard let source = PlaybackContextSourceDatabaseMapper.playbackSource(
            from: state.contextType,
            contextId: state.contextId,
            collectionCategory: state.collectionCategory,
            collectionValue: state.collectionValue,
            collectionArtistKey: state.collectionArtistKey
        ) else {
            PersistentLogger.log(
                "Player restore invalid playback context type=\(state.contextType.rawValue)"
            )
            // Невалидный источник нельзя повторно интерпретировать на следующем запуске.
            clearPersistedState(
                reason: "невалидные обязательные поля playback-контекста " +
                    "contextType=\(state.contextType.rawValue)"
            )
            publishConfirmedEmptyMiniPlayerState()
            return
        }

        let restoration = PendingLastTrackRestoration(
            identifier: UUID(),
            trackId: trackId,
            source: source,
            queueItemId: state.currentQueueItemId,
            duration: state.duration
        )
        pendingLastTrackRestoration = restoration

        switch source {
        case .playerQueue:
            restoreQueueContext(restorationIdentifier: restoration.identifier)
        case .trackList(let trackListId):
            restoreTrackListContext(
                trackListId: trackListId,
                restorationIdentifier: restoration.identifier
            )
        case .libraryFolder,
             .libraryRoot,
             .libraryCollection:
            // Для UI достаточно записи реестра; полный контекст по-прежнему ждёт готовности фонотеки.
            restoreLibraryTrackForDisplay(restorationIdentifier: restoration.identifier)
        }
    }

    /// Возобновляет только незавершённый стартовый путь после готовности bookmark-доступа и синхронизации.
    private func resumeLastTrackRestorationAfterLibraryAccess() {
        guard let restoration = pendingLastTrackRestoration else {
            return
        }

        PersistentLogger.log(
            "Player restore library access restored source=" +
                "\(playbackSourceLogDescription(restoration.source))"
        )

        switch restoration.source {
        case .libraryFolder,
             .libraryRoot,
             .libraryCollection:
            // Повторная быстрая проверка после sync подтверждает удаление, не полагаясь на старый снимок реестра.
            restoreLibraryTrackForDisplay(restorationIdentifier: restoration.identifier)
        case .playerQueue:
            // Fallback очереди может стать доступным только после открытия root-scope фонотеки.
            if currentTrackDisplayable == nil {
                restoreQueueContext(restorationIdentifier: restoration.identifier)
            }
        case .trackList:
            // Треклист не зависит от bookmark-доступа; незавершённая задача сама проверяет свой идентификатор.
            return
        }
    }

    /// Восстанавливает очередь по queueItemId, сохраняя различие между повторными вхождениями одного trackId.
    private func restoreQueueContext(restorationIdentifier: UUID) {
        guard let restoration = pendingRestoration(with: restorationIdentifier),
              restoration.source == .playerQueue,
              currentTrackDisplayable == nil
        else {
            return
        }

        if let queueItemId = restoration.queueItemId,
           let playerTrack = playlistManager.tracks.first(where: {
               $0.queueItemId == queueItemId
           }) {
            let queue: [any TrackDisplayable] = playlistManager.tracks
            PersistentLogger.log(
                "Player restore queueItemId=\(playerTrack.queueItemId) " +
                "currentId=\(playerTrack.id) queueCount=\(queue.count)"
            )
            applyRestoredTrack(
                playerTrack,
                context: queue,
                source: .playerQueue
            )
            completePendingRestoration(restorationIdentifier)
            return
        }

        if let queueItemId = restoration.queueItemId {
            PersistentLogger.log(
                "Player restore queue item not found: " +
                "queueItemId=\(queueItemId) trackId=\(restoration.trackId) " +
                "queueCount=\(playlistManager.tracks.count); using trackId fallback"
            )
        } else {
            PersistentLogger.log(
                "Player restore queue item id missing: " +
                "trackId=\(restoration.trackId); using trackId fallback"
            )
        }

        // Legacy-состояния без queueItemId сохраняют прежнее восстановление одиночного трека.
        restoreFallbackTrack(restorationIdentifier: restorationIdentifier)
    }

    /// Восстанавливает актуальный состав треклиста из SQLite без сохранения массива в player_state.
    private func restoreTrackListContext(
        trackListId: UUID,
        restorationIdentifier: UUID
    ) {
        guard var restoration = pendingRestoration(with: restorationIdentifier),
              restoration.isContextRestoreInFlight == false,
              currentTrackDisplayable == nil
        else {
            return
        }
        restoration.isContextRestoreInFlight = true
        pendingLastTrackRestoration = restoration

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.finishContextRestoreAttempt(restorationIdentifier)
            }

            guard let activeRestoration = self.pendingRestoration(with: restorationIdentifier),
                  self.currentTrackDisplayable == nil
            else {
                return
            }

            do {
                let trackList = try TrackListManager.shared.getTrackListById(trackListId)
                guard let restoredTrack = trackList.tracks.first(where: {
                    $0.trackId == activeRestoration.trackId
                }) else {
                    PersistentLogger.log(
                        "Player restore trackList track not found listId=\(trackListId) " +
                            "trackId=\(activeRestoration.trackId)"
                    )
                    self.confirmPendingTrackMissing(
                        restorationIdentifier,
                        reason: "currentTrackId отсутствует в восстановленном треклисте " +
                            "listId=\(trackListId) trackId=\(activeRestoration.trackId)"
                    )
                    return
                }

                let context: [any TrackDisplayable] = trackList.tracks
                PersistentLogger.log(
                    "Player restore trackListId=\(trackListId) " +
                    "trackId=\(restoredTrack.trackId) trackCount=\(context.count)"
                )
                self.applyRestoredTrack(
                    restoredTrack,
                    context: context,
                    source: .trackList(id: trackListId)
                )
                self.completePendingRestoration(restorationIdentifier)
            } catch {
                PersistentLogger.log(
                    "Player restore trackList failed listId=\(trackListId) error=\(error)"
                )
                self.confirmPendingTrackMissing(
                    restorationIdentifier,
                    reason: "треклист не найден или не загрузился listId=\(trackListId) error=\(error)"
                )
            }
        }
    }

    /// Быстро восстанавливает только display-модель library-трека без файла, bookmark и полного контекста.
    private func restoreLibraryTrackForDisplay(restorationIdentifier: UUID) {
        guard var restoration = pendingRestoration(with: restorationIdentifier),
              restoration.source.isLibrarySource,
              restoration.isFastLookupInFlight == false
        else {
            return
        }
        restoration.isFastLookupInFlight = true
        pendingLastTrackRestoration = restoration

        let wasLibraryAccessRestoredAtStart = isLibraryAccessRestored()
        PersistentLogger.log("Player restore fast track lookup started trackId=\(restoration.trackId)")

        Task { @MainActor [weak self] in
            guard let self else { return }

            let track = await self.fastLibraryTrackProvider.track(for: restoration.trackId)

            guard var activeRestoration = self.pendingRestoration(with: restorationIdentifier) else {
                return
            }
            activeRestoration.isFastLookupInFlight = false
            self.pendingLastTrackRestoration = activeRestoration
            PersistentLogger.log(
                "Player restore fast track lookup completed trackId=\(activeRestoration.trackId) " +
                    "found=\(track != nil)"
            )

            if let track {
                self.applyLibraryTrackForDisplay(
                    track,
                    restorationIdentifier: restorationIdentifier
                )
            }

            // Lookup, начатый до libraryAccessRestored, не может подтверждать удаление после sync.
            if wasLibraryAccessRestoredAtStart == false,
               self.isLibraryAccessRestored() {
                self.restoreLibraryTrackForDisplay(restorationIdentifier: restorationIdentifier)
                return
            }

            guard track != nil else {
                if self.isLibraryAccessRestored() {
                    self.confirmPendingTrackMissing(
                        restorationIdentifier,
                        reason: "трек отсутствует в реестре после восстановления фонотеки " +
                            "trackId=\(activeRestoration.trackId)"
                    )
                }
                return
            }

            if self.isLibraryAccessRestored() {
                self.restoreLibraryPlaybackContext(restorationIdentifier: restorationIdentifier)
            }
        }
    }

    /// Применяет раннюю модель только к UI: контекст, файл и AVPlayer остаются неподготовленными.
    private func applyLibraryTrackForDisplay(
        _ track: LibraryTrack,
        restorationIdentifier: UUID
    ) {
        guard let restoration = pendingRestoration(with: restorationIdentifier),
              currentTrackDisplayable == nil
        else {
            return
        }

        // Сохранённая длительность — безопасный UI fallback, пока AVAsset намеренно не читается.
        let displayTrack = LibraryTrack(
            id: track.id,
            fileURL: track.fileURL,
            title: track.title,
            artist: track.artist,
            duration: restoration.duration ?? track.duration,
            addedDate: track.addedDate,
            isAvailable: track.isAvailable
        )

        currentTrackDisplayable = displayTrack
        currentPlaybackContextSource = restoration.source
        currentContext = nil
        setPlaybackContextReady(false)
        isCurrentTrackPreparedForPlayback = false
        isPreparingCurrentTrackForPlayback = false
        currentTime = 0
        trackDuration = displayTrack.duration
        isPlaying = false
        miniPlayerStaticState = nil
        resetWaveformState()
        // Стартовый UI не запускает runtime snapshot: его builder открывает bookmark и читает аудиофайл.
        // Обложка и отсутствующие уточнения metadata будут запрошены только после готовности полного контекста или при Play.
        updateMiniPlayerStaticState(for: displayTrack)
        updateMiniPlayerProgressState()
        PersistentLogger.log(
            "Player restore UI track applied trackId=\(displayTrack.trackId) " +
                "source=\(playbackSourceLogDescription(restoration.source))"
        )
    }

    /// Загружает полный актуальный контекст только после готовности фонотеки, сохраняя уже показанный трек.
    private func restoreLibraryPlaybackContext(restorationIdentifier: UUID) {
        guard isLibraryAccessRestored(),
              var restoration = pendingRestoration(with: restorationIdentifier),
              restoration.source.isLibrarySource,
              restoration.isContextRestoreInFlight == false,
              currentTrackDisplayable?.trackId == restoration.trackId
        else {
            return
        }
        restoration.isContextRestoreInFlight = true
        pendingLastTrackRestoration = restoration
        PersistentLogger.log(
            "Player restore full context started source=" +
                "\(playbackSourceLogDescription(restoration.source)) trackId=\(restoration.trackId)"
        )

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.finishContextRestoreAttempt(restorationIdentifier)
            }

            guard let activeRestoration = self.pendingRestoration(with: restorationIdentifier) else {
                return
            }

            do {
                let tracks = try await self.loadLibraryContext(source: activeRestoration.source)

                guard self.pendingRestoration(with: restorationIdentifier) != nil,
                      self.currentTrackDisplayable?.trackId == activeRestoration.trackId
                else {
                    return
                }

                guard tracks.contains(where: { $0.trackId == activeRestoration.trackId }) else {
                    // Трек остался в реестре и уже показан; исчезновение только контекста не доказывает удаление файла.
                    PersistentLogger.log(
                        "Player restore full context has no current track source=" +
                            "\(self.playbackSourceLogDescription(activeRestoration.source)) " +
                            "trackId=\(activeRestoration.trackId)"
                    )
                    self.completePendingRestoration(restorationIdentifier)
                    return
                }

                self.applyRestoredLibraryPlaybackContext(
                    tracks,
                    restorationIdentifier: restorationIdentifier
                )
            } catch {
                // Ошибка контекста не очищает ранний UI-трек: его существование подтверждает отдельный реестр.
                PersistentLogger.log(
                    "Player restore full context failed source=" +
                        "\(self.playbackSourceLogDescription(activeRestoration.source)) error=\(error)"
                )
                self.completePendingRestoration(restorationIdentifier)
            }
        }
    }

    /// Возвращает полный список из существующего loader, не перенося SQLite-детали в ViewModel.
    private func loadLibraryContext(
        source: PlaybackContextSource
    ) async throws -> [LibraryTrack] {
        switch source {
        case .libraryFolder(let folderId):
            return try await libraryContextLoader.loadFolderContext(folderId: folderId)
        case .libraryRoot:
            return try await libraryContextLoader.loadRootContext()
        case .libraryCollection(let category, let rawValue, let artistKey):
            return try await libraryContextLoader.loadCollectionContext(
                category: category,
                rawValue: rawValue,
                artistKey: artistKey
            )
        case .playerQueue,
             .trackList:
            return []
        }
    }

    /// Обновляет только playback-контекст; ранняя display-модель остаётся на месте без мигания мини-плеера.
    private func applyRestoredLibraryPlaybackContext(
        _ tracks: [LibraryTrack],
        restorationIdentifier: UUID
    ) {
        guard let restoration = pendingRestoration(with: restorationIdentifier),
              let currentTrack = currentTrackDisplayable,
              currentTrack.trackId == restoration.trackId
        else {
            return
        }

        let context: [any TrackDisplayable] = tracks
        currentPlaybackContextSource = restoration.source
        currentContext = PlaybackContext.detect(from: context)
        _ = playbackContextStore.updateContext(
            currentTrack: currentTrack,
            context: context
        )
        setPlaybackContextReady(true)
        // Теперь bookmark-доступ уже восстановлен, поэтому вторичные runtime-данные можно догрузить отдельно от UI.
        requestSnapshotIfNeeded(for: currentTrack)
        completePendingRestoration(restorationIdentifier)
        updateMiniPlayerProgressState()
        PersistentLogger.log(
            "Player restore full context completed source=" +
                "\(playbackSourceLogDescription(restoration.source)) " +
                "trackId=\(currentTrack.trackId) contextCount=\(context.count)"
        )
    }

    /// Восстанавливает одиночный display-трек для старого состояния очереди без context-массива.
    private func restoreFallbackTrack(restorationIdentifier: UUID) {
        guard var restoration = pendingRestoration(with: restorationIdentifier),
              restoration.isFallbackTrackRestoreInFlight == false,
              currentTrackDisplayable == nil
        else {
            return
        }
        restoration.isFallbackTrackRestoreInFlight = true
        pendingLastTrackRestoration = restoration

        Task { @MainActor [weak self] in
            guard let self else { return }

            let restoredTrack = await self.restoreTrack(
                trackId: restoration.trackId,
                duration: restoration.duration
            )

            guard var activeRestoration = self.pendingRestoration(with: restorationIdentifier) else {
                return
            }
            activeRestoration.isFallbackTrackRestoreInFlight = false
            self.pendingLastTrackRestoration = activeRestoration

            guard let restoredTrack else {
                if self.isLibraryAccessRestored() {
                    self.confirmPendingTrackMissing(
                        restorationIdentifier,
                        reason: "fallback-трек не найден после восстановления доступа " +
                            "trackId=\(activeRestoration.trackId)"
                    )
                } else {
                    PersistentLogger.log(
                        "Player restore deferred: fallback track unavailable before " +
                            "libraryAccessRestored trackId=\(activeRestoration.trackId)"
                    )
                }
                return
            }

            guard self.currentTrackDisplayable == nil else {
                return
            }
            self.applyRestoredTrack(
                restoredTrack,
                context: [restoredTrack],
                source: .playerQueue
            )
            self.completePendingRestoration(restorationIdentifier)
        }
    }

    /// Возвращает незавершённое восстановление только при совпадении идентификатора async-операции.
    private func pendingRestoration(
        with identifier: UUID
    ) -> PendingLastTrackRestoration? {
        guard let restoration = pendingLastTrackRestoration,
              restoration.identifier == identifier
        else {
            return nil
        }

        return restoration
    }

    /// Завершает восстановление после успешного применения UI или полного контекста.
    private func completePendingRestoration(_ identifier: UUID) {
        guard pendingRestoration(with: identifier) != nil else { return }
        pendingLastTrackRestoration = nil
    }

    /// Сбрасывает только стартовую операцию, когда пользователь уже выбрал другой трек.
    private func invalidatePendingLastTrackRestoration() {
        pendingLastTrackRestoration = nil
    }

    /// Снимает флаг in-flight, не затрагивая результат, который мог завершить восстановление раньше defer.
    private func finishContextRestoreAttempt(_ identifier: UUID) {
        guard var restoration = pendingRestoration(with: identifier) else { return }
        restoration.isContextRestoreInFlight = false
        pendingLastTrackRestoration = restoration
    }

    /// Подтверждает отсутствие трека только после готовности соответствующего источника и очищает UI вместе с state.
    private func confirmPendingTrackMissing(
        _ identifier: UUID,
        reason: String
    ) {
        guard let restoration = pendingRestoration(with: identifier),
              currentTrackDisplayable == nil || currentTrackDisplayable?.trackId == restoration.trackId
        else {
            return
        }

        clearPersistedState(reason: reason)
        pendingLastTrackRestoration = nil

        if currentTrackDisplayable?.trackId == restoration.trackId {
            playerManager.pause()
            playerManager.stopAccessingCurrentTrack()
            currentTrackDisplayable = nil
            currentContext = nil
            setPlaybackContextReady(false)
            currentPlaybackContextSource = .playerQueue
            currentTime = 0
            trackDuration = 0
            isPlaying = false
            isCurrentTrackPreparedForPlayback = false
            isPreparingCurrentTrackForPlayback = false
            miniPlayerStaticState = nil
            resetWaveformState()
        }

        publishConfirmedEmptyMiniPlayerState()
    }

    /// Публикует empty только после окончательного отсутствия или невалидности сохранённого трека.
    private func publishConfirmedEmptyMiniPlayerState() {
        guard currentTrackDisplayable == nil else { return }
        setPlaybackContextReady(false)
        miniPlayerStaticState = nil
        miniPlayerState = .empty
    }

    /// Публикует loading до того, как SQLite подтвердит наличие или отсутствие сохранённого состояния.
    private func publishLastTrackRestorationLoading() {
        guard currentTrackDisplayable == nil,
              miniPlayerState != .loading(staticState: nil)
        else {
            return
        }

        miniPlayerStaticState = nil
        miniPlayerState = .loading(staticState: nil)
    }

    /// Восстанавливает display-модель локального или доступного iTunes-трека по стабильному trackId.
    private func restoreTrack(
        trackId: UUID,
        duration: TimeInterval?
    ) async -> (any TrackDisplayable)? {
        let registryEntry = await TrackRegistry.shared.entry(for: trackId)

        if registryEntry?.source != .purchasedITunes,
           let url = await BookmarkResolver.url(forTrack: trackId),
           FileManager.default.fileExists(atPath: url.path) {
            // LibraryTrack является общей display-моделью для восстановленного локального файла.
            return LibraryTrack(
                id: trackId,
                fileURL: url,
                title: nil,
                artist: nil,
                duration: duration ?? 0,
                addedDate: registryEntry?.fileDate ?? Date(),
                isAvailable: true
            )
        }

        // Для iTunes используется существующий provider и тот же UUID.v5 из persistentID.
        let purchasedTrack = PurchasedITunesMusicProvider()
            .loadTracks()
            .map(PurchasedITunesPlayableTrack.init(track:))
            .first(where: { $0.trackId == trackId })

        return purchasedTrack
    }

    /// Применяет восстановленную модель и контекст только к интерфейсному playback-состоянию.
    /// AVPlayerItem создаётся позднее первым нажатием Play.
    private func applyRestoredTrack(
        _ track: any TrackDisplayable,
        context: [any TrackDisplayable],
        source: PlaybackContextSource
    ) {
        guard currentTrackDisplayable == nil else { return }

        currentTrackDisplayable = track
        currentPlaybackContextSource = source
        currentContext = PlaybackContext.detect(from: context)
        _ = playbackContextStore.updateContext(
            currentTrack: track,
            context: context
        )
        setPlaybackContextReady(true)
        isCurrentTrackPreparedForPlayback = false
        isPreparingCurrentTrackForPlayback = false
        currentTime = 0
        trackDuration = track.duration
        isPlaying = false
        miniPlayerStaticState = nil
        resetWaveformState()
        requestSnapshotIfNeeded(for: track)
        updateMiniPlayerStaticState(for: track)
        updateMiniPlayerProgressState()
        PersistentLogger.log(
            "Player state restore success: trackId=\(track.trackId) " +
            "source=\(playbackSourceLogDescription(source)) contextCount=\(context.count)"
        )
    }

    /// Удаляет запись, если последний трек больше нельзя восстановить.
    private func clearPersistedState(reason: String) {
        PersistentLogger.log("Player state clear: причина=\(reason)")

        guard let statePersistence else {
            PersistentLogger.log("Player state clear skipped: хранилище состояния недоступно")
            return
        }

        do {
            try statePersistence.clearState()
        } catch {
            PersistentLogger.log("PlayerViewModel: ошибка очистки состояния плеера: \(error)")
        }
    }

    /// Очищает UI и сохранённое состояние, когда удалён текущий элемент очереди.
    private func handlePlaylistChanged(_ tracks: [PlayerTrack]) {
        guard let current = currentTrackDisplayable as? PlayerTrack,
              tracks.contains(where: { $0.queueItemId == current.queueItemId }) == false,
              let statePersistence
        else {
            return
        }

        do {
            guard let state = try statePersistence.loadState(),
                  state.currentTrackId == current.trackId,
                  state.currentQueueItemId == nil || state.currentQueueItemId == current.queueItemId
            else {
                return
            }

            PersistentLogger.log(
                "Player state clear: причина=удалён текущий элемент очереди " +
                "queueItemId=\(current.queueItemId) trackId=\(current.trackId)"
            )
            try statePersistence.clearState()
        } catch {
            PersistentLogger.log("PlayerViewModel: ошибка очистки удалённого состояния плеера: \(error)")
            return
        }

        playerManager.pause()
        playerManager.stopAccessingCurrentTrack()
        invalidatePendingLastTrackRestoration()
        currentTrackDisplayable = nil
        currentContext = nil
        setPlaybackContextReady(false)
        currentPlaybackContextSource = .playerQueue
        currentTime = 0
        trackDuration = 0
        isPlaying = false
        isCurrentTrackPreparedForPlayback = false
        isPreparingCurrentTrackForPlayback = false
        miniPlayerStaticState = nil
        resetWaveformState()
        updateMiniPlayerProgressState()
    }

    /// Формирует безопасное описание источника без URL и security-scoped bookmark-данных.
    private func playbackSourceLogDescription(_ source: PlaybackContextSource) -> String {
        switch source {
        case .playerQueue:
            return "playerQueue"
        case .trackList(let id):
            return "trackList id=\(id)"
        case .libraryFolder(let id):
            return "libraryFolder id=\(id)"
        case .libraryRoot:
            return "libraryRoot"
        case .libraryCollection(let category, let rawValue, let artistKey):
            return "libraryCollection category=\(category.rawValue) " +
                "rawValue=\(rawValue) artistKey=\(artistKey ?? "nil")"
        }
    }

    /// Формирует полное безопасное описание сохранённого состояния без URL и bookmark-данных.
    private func playerStateLogDescription(_ state: PlayerStateDatabaseModel) -> String {
        let queueItemId = state.currentQueueItemId?.uuidString ?? "nil"
        let trackId = state.currentTrackId?.uuidString ?? "nil"
        let contextId = state.contextId?.uuidString ?? "nil"
        let category = state.collectionCategory ?? "nil"
        let value = state.collectionValue ?? "nil"
        let artistKey = state.collectionArtistKey ?? "nil"
        let duration = state.duration.map { String($0) } ?? "nil"

        return [
            "id=\(state.id)",
            "currentQueueItemId=\(queueItemId)",
            "currentTrackId=\(trackId)",
            "contextType=\(state.contextType.rawValue)",
            "contextId=\(contextId)",
            "collectionCategory=\(category)",
            "collectionValue=\(value)",
            "collectionArtistKey=\(artistKey)",
            "playbackTime=\(state.playbackTime)",
            "duration=\(duration)",
            "isPlaying=\(state.isPlaying)",
            "repeatMode=\(state.repeatMode.rawValue)",
            "shuffleEnabled=\(state.shuffleEnabled)",
            "updatedAt=\(state.updatedAt)"
        ].joined(separator: " ")
    }

    /// Переводит ошибку чтения player_state в конкретную причину очистки.
    private func stateLoadClearReason(for error: Error) -> String {
        guard let databaseError = error as? DatabaseError else {
            return "ошибка чтения состояния SQLite: \(error)"
        }

        switch databaseError {
        case .invalidColumnValue(let column, let value):
            if column == DatabaseSchema.PlayerState.contextType {
                return "невалидный context_type value=\(value)"
            }

            if column == DatabaseSchema.PlayerState.repeatMode {
                return "невалидный repeat_mode value=\(value)"
            }

            return "некорректное значение SQLite-колонки column=\(column) value=\(value)"
        case .missingRequiredColumn(let name):
            return "отсутствует обязательная SQLite-колонка name=\(name)"
        default:
            return "ошибка чтения состояния SQLite: \(error)"
        }
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
                requestNowPlayingArtworkIfNeeded(for: current)
            }
        }
    }

    /// Запрашивает runtime snapshot только для треков, которые живут в bookmark-pipeline приложения.
    private func requestSnapshotIfNeeded(
        for track: any TrackDisplayable
    ) {
        guard !track.isPurchasedITunesRuntimeTrack else {
            // iTunes-трек уже содержит данные обложки и не должен попадать в BookmarkResolver.
            requestNowPlayingArtworkIfNeeded(for: track)
            return
        }

        requestSnapshotIfNeeded(for: track.trackId)
        // Если snapshot уже был загружен строкой списка, отдельно запускаем только Now Playing artwork.
        requestNowPlayingArtworkIfNeeded(for: track)
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
            requestNowPlayingArtworkIfNeeded(for: current)
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
            requestNowPlayingArtworkIfNeeded(for: current)
        }
    }

    /// Подписывает системный Now Playing на готовую обложку общей подсистемы.
    private func requestNowPlayingArtworkIfNeeded(
        for track: any TrackDisplayable
    ) {
        let artworkData: Data?
        let sourceIdentifier: ArtworkSourceIdentifier?
        let revision: Date?

        if let purchasedTrack = track as? (
            any TrackDisplayable & PurchasedITunesTrackRepresentable
        ), purchasedTrack.isPurchasedITunesRuntimeTrack {
            artworkData = purchasedTrack.artworkData
            sourceIdentifier = ArtworkSourceIdentifier.mediaLibrary(
                trackId: track.trackId
            )
            revision = nil
        } else {
            let snapshot = runtimeSnapshotController.snapshot(for: track.trackId)
            artworkData = snapshot?.artworkData
            sourceIdentifier = snapshot?.artworkSourceIdentifier
            revision = snapshot?.updatedAt
        }

        guard artworkData != nil, sourceIdentifier != nil else { return }

        Task {
            let changedTrackId = await runtimeSnapshotController.requestNowPlayingArtworkIfNeeded(
                for: track.trackId,
                artworkData: artworkData,
                sourceIdentifier: sourceIdentifier,
                revision: revision
            )
            guard changedTrackId != nil,
                  let current = currentTrackDisplayable,
                  current.trackId == track.trackId else {
                return
            }

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

    // MARK: - Waveform

    /// Отменяет работу прежнего трека и немедленно убирает его данные из интерфейса.
    private func resetWaveformState() {
        waveformTask?.cancel()
        waveformTask = nil
        waveformState = .unavailable
    }

    /// Запускает генерацию после контрольной точки PlayerManager, не ожидая завершения загрузки duration.
    private func loadWaveformIfPossible(
        for preparedLocalFile: PlayerPreparedLocalFile
    ) {
        let trackId = preparedLocalFile.trackId

        guard currentTrackDisplayable?.trackId == trackId else {
            // Поздний сигнал прежнего трека не должен отменять уже начатую задачу нового selection.
            return
        }

        waveformTask?.cancel()
        waveformTask = nil
        waveformState = .unavailable

        waveformState = .loading
        let waveformGenerator = waveformGenerator
        let fileURL = preparedLocalFile.fileURL

        waveformTask = Task { [weak self] in
            do {
                let samples = try await waveformGenerator.generateSamples(
                    from: fileURL,
                    cacheKey: trackId.uuidString,
                    sampleCount: PlayerWaveformConfiguration.miniPlayerSampleCount
                )

                guard !Task.isCancelled,
                      let self,
                      self.currentTrackDisplayable?.trackId == trackId
                else {
                    // Результат старого трека нельзя публиковать после быстрой смены selection.
                    return
                }

                self.waveformState = .ready(samples)
            } catch is CancellationError {
                // Отмена штатна при смене текущего трека и не является ошибкой playback.
            } catch {
                guard !Task.isCancelled,
                      let self,
                      self.currentTrackDisplayable?.trackId == trackId
                else {
                    return
                }

                // Ошибка производных данных не влияет на AVPlayer и оставляет доступный fallback ProgressBar.
                self.waveformState = .failed
                PersistentLogger.log(
                    "Player waveform failed trackId=\(trackId) error=\(error)"
                )
            }
        }
    }

    /// Публикует состояние мини-плеера без изменения существующей playback-логики.
    private func updateMiniPlayerState() {
        guard currentTrackDisplayable != nil else {
            miniPlayerStaticState = nil
            // Пока есть незавершённый стартовый путь, отсутствие модели не подтверждает пустой плеер.
            if pendingLastTrackRestoration != nil {
                miniPlayerState = .loading(staticState: nil)
            } else {
                miniPlayerState = .empty
            }
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
        updateTrackNavigationAvailability()
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
    
    /// Запускает трек в заданном playback-контексте.
    func play(
        track: any TrackDisplayable,
        context: [any TrackDisplayable] = [],
        source: PlaybackContextSource = .playerQueue
    ) {
        
        // Определяем контекст воспроизведения
        let contextType = PlaybackContext.detect(from: context)
        let isSameContext = playbackContextStore.isCurrentContext(context)
        let isSameTrack: Bool
        if let current = currentTrackDisplayable {
            isSameTrack = current.id == track.id &&
                type(of: current) == type(of: track) &&
                currentContext == contextType &&
                isSameContext &&
                currentPlaybackContextSource == source
        } else {
            isSameTrack = false
        }

        currentContext = contextType
        currentPlaybackContextSource = source

        // Обновляем контекст до проверки текущего трека, чтобы не потерять его позицию.
        _ = playbackContextStore.updateContext(
            currentTrack: track,
            context: context
        )
        // Пользовательский выбор получает готовый контекст только если вызывающий слой передал непустой массив с треком.
        let hasConfirmedPlaybackContext = context.contains { candidate in
            candidate.id == track.id && type(of: candidate) == type(of: track)
        }

        // Если это тот же уже загруженный трек и тот же контекст — просто продолжить.
        if isSameTrack && isCurrentTrackPreparedForPlayback {
            setPlaybackContextReady(hasConfirmedPlaybackContext)
            playerManager.playCurrent()
            isPlaying = true
            updateMiniPlayerProgressState()
            return
        }

        // Повторное действие не должно параллельно готовить один и тот же AVPlayerItem.
        if isSameTrack && isPreparingCurrentTrackForPlayback {
            setPlaybackContextReady(hasConfirmedPlaybackContext)
            return
        }
        
        // Новый трек: останавливаем доступ к старому
        invalidatePendingLastTrackRestoration()
        playerManager.stopAccessingCurrentTrack()
        resetWaveformState()
        currentTrackDisplayable = track
        setPlaybackContextReady(hasConfirmedPlaybackContext)
        miniPlayerStaticState = nil
        currentTime = 0
        trackDuration = 0
        isCurrentTrackPreparedForPlayback = false
        isPreparingCurrentTrackForPlayback = true
        persistCurrentTrack(track, source: source)
        requestSnapshotIfNeeded(for: track)
        
        updateMiniPlayerStaticState(for: track)
        updateMiniPlayerProgressState()
        
        // Стартуем воспроизведение через PlayerManager
        let playbackRequestTrackId = track.trackId
        Task { @MainActor in
            defer {
                // Позднее завершение старой задачи не может снять защиту подготовки нового выбранного трека.
                if currentTrackDisplayable?.trackId == playbackRequestTrackId {
                    isPreparingCurrentTrackForPlayback = false
                }
            }

            do {
                // Для iTunes-источника передаём в PlayerManager адаптер с assetURL,
                // а currentTrackDisplayable оставляем исходным для подсветки контекста.
                let playbackTrack = playbackTrack(for: track)
                try await playerManager.play(
                    track: playbackTrack,
                    onPreparedLocalFile: { [weak self] preparedLocalFile in
                        // ViewModel запускает waveform до получения duration; PlayerManager не знает о кэше и генераторе.
                        self?.loadWaveformIfPossible(for: preparedLocalFile)
                    }
                )
                guard currentTrackDisplayable?.trackId == track.trackId else {
                    // Асинхронный запуск прежнего трека не должен менять waveform нового selection.
                    return
                }
                isCurrentTrackPreparedForPlayback = true
                isPlaying = true
                updateMiniPlayerProgressState()
                // Первичное заполнение Now Playing Info (duration ещё может быть 0)
                playerManager.applyNowPlaying(snapshot: makeNowPlayingSnapshot(for: track))
                startObservingProgress()
            } catch let appError as AppError {
                isCurrentTrackPreparedForPlayback = false
                isPlaying = false
                updateMiniPlayerProgressState()
                toastPresenter.handle(appError)
            } catch {
                isCurrentTrackPreparedForPlayback = false
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

    /// Подключает единственное наблюдение прогресса для обычного и восстановленного запуска.
    private func startObservingProgress() {
        playerManager.observeProgress { [weak self] time in
            guard let self else { return }
            self.currentTime = time
            // Источник уже ограничен четырьмя обновлениями в секунду, поэтому progress публикуется без второго throttle.
            self.updateMiniPlayerProgressState()
            let now = CACurrentMediaTime()
            // Now Playing: 1 Hz.
            if now - self.lastNowPlayingTick >= 1.0 {
                self.lastNowPlayingTick = now
                self.playerManager.applyPlaybackTime(currentTime: time, isPlaying: self.isPlaying)
            }
        }
    }

    /// Загружает восстановленный трек в PlayerManager только после первого нажатия Play.
    private func prepareAndPlayRestoredTrack(_ track: any TrackDisplayable) {
        guard isPreparingCurrentTrackForPlayback == false else {
            return
        }

        isPreparingCurrentTrackForPlayback = true
        let playbackRequestTrackId = track.trackId

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                // Завершение устаревшего запуска не может снять защиту нового выбранного трека.
                if self.currentTrackDisplayable?.trackId == playbackRequestTrackId {
                    self.isPreparingCurrentTrackForPlayback = false
                }
            }

            do {
                let playbackTrack = self.playbackTrack(for: track)
                try await self.playerManager.play(
                    track: playbackTrack,
                    onPreparedLocalFile: { [weak self] preparedLocalFile in
                        // Восстановленный трек использует тот же ранний сигнал без второго обращения к bookmark.
                        self?.loadWaveformIfPossible(for: preparedLocalFile)
                    }
                )
                guard self.currentTrackDisplayable?.trackId == track.trackId else {
                    // Восстановленный запуск мог устареть до завершения подготовки файла.
                    return
                }
                self.isCurrentTrackPreparedForPlayback = true
                self.isPlaying = true
                self.updateMiniPlayerProgressState()
                self.playerManager.applyNowPlaying(snapshot: self.makeNowPlayingSnapshot(for: track))
                self.startObservingProgress()
            } catch let appError as AppError {
                self.isCurrentTrackPreparedForPlayback = false
                self.isPlaying = false
                self.updateMiniPlayerProgressState()
                self.toastPresenter.handle(appError)
            } catch {
                self.isCurrentTrackPreparedForPlayback = false
                self.isPlaying = false
                self.updateMiniPlayerProgressState()
                self.toastPresenter.handle(
                    .playbackFailed(title: track.title ?? track.fileName)
                )
            }
        }
    }

    /// Обновляет мини-плеер и Now Playing после изменения состояния воспроизведения.
    private func applyCurrentPlaybackState() {
        updateMiniPlayerProgressState()
        lastNowPlayingTick = 0
        playerManager.applyPlaybackTime(currentTime: currentTime, isPlaying: isPlaying)

        if let current = currentTrackDisplayable {
            playerManager.applyNowPlaying(snapshot: makeNowPlayingSnapshot(for: current))
        }
    }

    // MARK: - Управление воспроизведением

    /// Переключает состояние текущего трека через доменный сервис без оптимистического изменения ViewModel.
    func toggleCurrentTrackFavorite() {
        guard let currentTrack = currentTrackDisplayable else {
            return
        }

        do {
            _ = try favoritesService.toggle(
                FavoriteTrackInput(playerTrack: currentTrack)
            )
        } catch {
            // Состояние меняет только успешно доставленное FavoritesChangeEvent.
            PersistentLogger.log(
                "PlayerViewModel: ошибка переключения избранного trackId=\(currentTrack.trackId) error=\(error)"
            )
        }
    }

    /// Применяет итоговое состояние системной команды через идемпотентные операции доменного сервиса.
    ///
    /// - Returns: `true`, если операция была принята сервисом без ошибки сохранения.
    @discardableResult
    func setCurrentTrackFavorite(_ isFavorite: Bool) -> Bool {
        guard let currentTrack = currentTrackDisplayable else {
            return false
        }

        do {
            if isFavorite {
                _ = try favoritesService.add(
                    FavoriteTrackInput(playerTrack: currentTrack)
                )
            } else {
                _ = try favoritesService.remove(trackId: currentTrack.trackId)
            }

            return true
        } catch {
            // Состояние интерфейса и системной команды меняет только успешно доставленное событие Favorites.
            PersistentLogger.log(
                "PlayerViewModel: ошибка установки избранного trackId=\(currentTrack.trackId) " +
                    "isFavorite=\(isFavorite) error=\(error)"
            )
            return false
        }
    }

    func togglePlayPause() {
        if isPlaying {
            playerManager.pause()
            isPlaying = false
            applyCurrentPlaybackState()
            return
        }

        guard let currentTrack = currentTrackDisplayable else { return }

        if isCurrentTrackPreparedForPlayback {
            playerManager.playCurrent()
            isPlaying = true
            applyCurrentPlaybackState()
            return
        }

        prepareAndPlayRestoredTrack(currentTrack)
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
        guard isPlaybackContextReady,
              canPlayNextTrack else {
            return
        }

        _ = startNextTrack()
    }

    /// Запускает следующий трек и сообщает, был ли найден переход.
    @discardableResult
    private func startNextTrack() -> Bool {
        guard isPlaybackContextReady,
              canPlayNextTrack,
              let current = currentTrackDisplayable,
              let next = playbackContextStore.nextTrack(after: current) else {
            return false
        }

        if next.track.id == current.id,
           type(of: next.track) == type(of: current) {
            restartCurrentTrack()
        } else {
            play(
                track: next.track,
                context: next.context,
                source: currentPlaybackContextSource
            )
        }
        return true
    }
    
    /// Предыдущий трек в текущем контексте
    func playPreviousTrack() {
        guard isPlaybackContextReady,
              canPlayPreviousTrack,
              let current = currentTrackDisplayable else {
            return
        }
        
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

        play(
            track: previous.track,
            context: previous.context,
            source: currentPlaybackContextSource
        )
    }
    
    
    // MARK: - Проверка "текущего" трека
    
    func isCurrent(_ track: any TrackDisplayable, in context: PlaybackContext) -> Bool {
        guard let current = currentTrackDisplayable,
              let currentCtx = currentContext else { return false }
        
        return current.id == track.id && currentCtx == context
    }
    
    
    
    // MARK: - Деинициализация
    
    deinit {
        waveformTask?.cancel()
        if let libraryAccessRestoredObserver {
            NotificationCenter.default.removeObserver(libraryAccessRestoredObserver)
        }
        playerManager.removeTimeObserver()
        playerManager.removeFavoriteCommandHandler()
    }
}

private extension PlaybackContextSource {

    /// Отделяет контексты фонотеки, для которых display-модель приходит из TrackRegistry до готовности bookmark-доступа.
    var isLibrarySource: Bool {
        switch self {
        case .libraryFolder,
             .libraryRoot,
             .libraryCollection:
            return true
        case .playerQueue,
             .trackList:
            return false
        }
    }
}
