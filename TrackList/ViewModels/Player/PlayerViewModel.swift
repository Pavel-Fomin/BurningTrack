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
    
    @Published var currentTrackDisplayable: (any TrackDisplayable)? {
        didSet {
            let didChangeDisplayableIdentity: Bool
            switch (oldValue, currentTrackDisplayable) {
            case let (oldTrack?, currentTrack?):
                didChangeDisplayableIdentity = oldTrack.id != currentTrack.id
                    || type(of: oldTrack) != type(of: currentTrack)

            case (nil, nil):
                didChangeDisplayableIdentity = false

            case (nil, _),
                 (_, nil):
                didChangeDisplayableIdentity = true
            }
            guard didChangeDisplayableIdentity else {
                return
            }

            // Новая строка не наследует intent предыдущего перехода, даже если физический trackId повторяется.
            activeTrackChangeReason = .passive
            automaticListScrollTrigger = nil

            if oldValue?.trackId != currentTrackDisplayable?.trackId {
                refreshCurrentTrackFavoriteState()
            }
        }
    }
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0.0
    @Published var trackDuration: TimeInterval = 0.0
    @Published var currentContext: PlaybackContext?
    /// Причина последней смены строки остаётся в playback-state, но не выполняет UI-effect сама.
    @Published private(set) var activeTrackChangeReason: ActiveTrackChangeReason = .passive
    /// Одноразовый intent передаётся в feature-local ScreenState только для явной навигации MiniPlayer.
    @Published private(set) var automaticListScrollTrigger: AutomaticListScrollTrigger?
    /// Показывает, что для текущего трека получен достоверный playback-массив, а не только ранняя display-модель.
    @Published private(set) var isPlaybackContextReady = false
    /// Разрешает переход к предыдущему треку только после проверки готового playback-контекста.
    @Published private(set) var canPlayPreviousTrack = false
    /// Разрешает переход к следующему треку только после проверки готового playback-контекста.
    @Published private(set) var canPlayNextTrack = false
    /// Публикуемое зеркало controller-а для представления; источником загрузки и обновления snapshot остаётся `PlayerRuntimeSnapshotController`.
    @Published private(set) var snapshotsByTrackId: [UUID: TrackRuntimeSnapshot] = [:]
    /// Подтверждённые идентификаторы «Избранного» для presentation-состояния строк.
    @Published private(set) var favoriteTrackIds: Set<UUID> = []
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
    
    // MARK: - Состояние MiniPlayer

    /// Единое явное состояние отображения мини-плеера.
    /// До чтения player_state отсутствие трека ещё не подтверждено, поэтому UI начинает с loading.
    @Published private(set) var miniPlayerState: MiniPlayerState = .loading(staticState: nil)

    /// Статические данные сохраняются между обновлениями прогресса.
    private var miniPlayerStaticState: MiniPlayerStaticState?

    /// Производное состояние waveform хранится отдельно от часто обновляемого состояния прогресса.
    @Published private(set) var waveformState: PlayerWaveformState = .unavailable
    /// Задача существует только для текущего трека и отменяется до запуска следующей генерации.
    private var waveformTask: Task<Void, Never>?
    /// Task подготовки принадлежит текущему пользовательскому запуску и отменяется до смены request ownership.
    private var playbackTask: Task<Void, Never>?
    /// ViewModel хранит только ссылку на identity, созданную PlayerManager, чтобы не иметь второго источника request-state.
    private var activePlaybackRequestID: PlaybackRequestID?
    
    // MARK: - Ограничение частоты

    private var lastNowPlayingTick: CFTimeInterval = 0
    
    // MARK: - Внутренние зависимости
    
    private let playerManager: any PlayerManaging
    private let playbackContextStore: PlayerPlaybackContextStore
    private let nowPlayingSnapshotBuilder: any NowPlayingSnapshotBuilding
    private let runtimeSnapshotController: PlayerRuntimeSnapshotController
    private let eventObserver: any PlayerEventObserving
    /// Выполняет доменные операции «Избранного», не раскрывая ViewModel работу с треклистами.
    private let favoritesService: any FavoritesServicing
    /// Общий маршрут toggle используется мини-плеером и меню треков.
    private let favoriteActionHandler: FavoriteTrackActionHandler
    /// Передаёт точечные изменения «Избранного» для presentation-состояния приложения.
    private let favoritesEvents: any FavoritesEventsObserving
    /// Показывает пользовательские ошибки без прямой зависимости от ToastManager.shared.
    private let toastPresenter: any ToastPresenting
    /// Изолирует постоянное состояние выбранного трека от playback- и UI-логики.
    private let statePersistence: (any PlayerStatePersisting)?
    /// Очередь используется для восстановления PlayerTrack и проверки удаления текущего элемента.
    private let playlistManager: PlaylistManager
    /// Загружает актуальные списки фонотеки без переноса SQLite-логики в PlayerViewModel.
    private let libraryContextLoader: any LibraryPlaybackContextLoading
    /// Загружает полный отсортированный контекст системной медиатеки без зависимости от экранной ViewModel.
    private let purchasedITunesContextLoader: any PurchasedITunesPlaybackContextLoading
    /// Быстро получает один display-трек из SQLite-реестра без открытия файла и bookmark-доступа.
    private let fastLibraryTrackProvider: any FastLibraryTrackProviding
    /// Показывает, завершена ли окончательная синхронизация фонотеки.
    /// Используется только для подтверждения отсутствия трека и финальной проверки контекста.
    private let isLibraryAccessRestored: @MainActor () -> Bool
    /// Слой генерации скрывает AVAssetReader и файловый кэш от ViewModel.
    private let waveformGenerator: any WaveformGenerating
    /// Читает только настройку, нужную для построения static state мини-плеера.
    private let isTagReadingEnabled: @MainActor () -> Bool
    /// Показывает, что текущий трек восстановлен для интерфейса, но ещё не загружен в PlayerManager.
    private var isCurrentTrackPreparedForPlayback = false
    /// Не допускает параллельную подготовку одного ранне восстановленного трека по быстрым повторным нажатиям Play.
    private var isPreparingCurrentTrackForPlayback = false
    /// Источник текущего playback-контекста нужен для сохранения его при переходе Next/Previous.
    /// Источник контекста публикуется вместе с остальным playback-состоянием без отдельного хранилища.
    @Published private(set) var currentPlaybackContextSource: PlaybackContextSource = .playerQueue
    /// Наблюдатель нужен для повторной попытки восстановления локального трека после открытия bookmark-доступа.
    private var libraryAccessRestoredObserver: NSObjectProtocol?
    /// Наблюдатель повторяет только отложенное восстановление iTunes после ответа на системный запрос MediaPlayer.
    private var purchasedITunesAccessChangedObserver: NSObjectProtocol?
    /// Хранит Combine-подписки PlayerViewModel на протяжении её жизненного цикла.
    private var cancellables = Set<AnyCancellable>()

    /// Определяет назначение загрузки локального контекста воспроизведения.
    private enum LibraryContextRestorationStage {
        /// Ранний контекст строится из SQLite до завершения синхронизации.
        case preliminary
        /// Окончательный контекст повторно проверяется после libraryAccessRestored.
        case final
    }

    /// Хранит только незавершённое стартовое восстановление, не дублируя данные в SQLite или отдельном кэше.
    private struct PendingLastTrackRestoration {
        /// Идентификатор отделяет устаревшие async-результаты от текущего выбора пользователя.
        let identifier: UUID
        /// Стабильный id сохранённого трека для быстрой и полной проверок.
        let trackId: UUID
        /// Исходный контекст нужен позднему восстановлению порядка Next/Previous и уточняется только для распознанного сохранённого iTunes-состояния.
        var source: PlaybackContextSource
        /// Queue item сохраняет точную позицию среди повторных вхождений одного trackId.
        let queueItemId: UUID?
        /// Сохранённая длительность применяется только как UI fallback до загрузки runtime-данных.
        let duration: TimeInterval?
        /// Не допускает параллельные чтения одного трека из реестра.
        var isFastLookupInFlight = false
        /// Не допускает параллельные fallback-проверки очереди через bookmark-путь.
        var isFallbackTrackRestoreInFlight = false
        /// Не допускает параллельные загрузки локального контекста воспроизведения.
        var isContextRestoreInFlight = false
        /// Показывает, что предварительный контекст уже построен из SQLite,
        /// но ещё не проверен после окончательной синхронизации фонотеки.
        var hasPreliminaryLibraryContext = false
        /// Запоминает единственное событие готовности MediaPlayer, пришедшее во время чтения старого iTunes-контекста.
        var shouldRetryPurchasedITunesContext = false
    }

    /// Ненулевое значение означает, что отображение, предварительный или окончательный контекст стартового трека ещё восстанавливаются.
    private var pendingLastTrackRestoration: PendingLastTrackRestoration?

    // MARK: - Снимок Now Playing

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
            isPlaying: isPlaying,
            shouldShowTags: isTagReadingEnabled()
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
        playerManager: any PlayerManaging,
        playbackContextStore: PlayerPlaybackContextStore,
        nowPlayingSnapshotBuilder: any NowPlayingSnapshotBuilding = NowPlayingSnapshotBuilder(),
        runtimeSnapshotController: PlayerRuntimeSnapshotController,
        eventObserver: any PlayerEventObserving,
        toastPresenter: any ToastPresenting,
        statePersistence: (any PlayerStatePersisting)?,
        playlistManager: PlaylistManager,
        libraryContextLoader: any LibraryPlaybackContextLoading,
        purchasedITunesContextLoader: any PurchasedITunesPlaybackContextLoading,
        fastLibraryTrackProvider: any FastLibraryTrackProviding,
        isLibraryAccessRestored: @escaping @MainActor () -> Bool,
        waveformGenerator: any WaveformGenerating,
        isTagReadingEnabled: @escaping @MainActor () -> Bool = { true },
        favoritesService: any FavoritesServicing,
        favoriteActionHandler: FavoriteTrackActionHandler,
        favoritesEvents: any FavoritesEventsObserving
    ) {
        self.playerManager = playerManager
        // Composition Root создаёт Store и синхронно восстанавливает режим до первого контекста.
        self.playbackContextStore = playbackContextStore
        self.nowPlayingSnapshotBuilder = nowPlayingSnapshotBuilder
        self.runtimeSnapshotController = runtimeSnapshotController
        self.eventObserver = eventObserver
        self.favoritesService = favoritesService
        self.favoriteActionHandler = favoriteActionHandler
        self.favoritesEvents = favoritesEvents
        self.toastPresenter = toastPresenter
        self.statePersistence = statePersistence
        self.playlistManager = playlistManager
        self.libraryContextLoader = libraryContextLoader
        self.purchasedITunesContextLoader = purchasedITunesContextLoader
        self.fastLibraryTrackProvider = fastLibraryTrackProvider
        self.isLibraryAccessRestored = isLibraryAccessRestored
        self.waveformGenerator = waveformGenerator
        self.isTagReadingEnabled = isTagReadingEnabled
        if self.statePersistence == nil {
            PersistentLogger.log("PlayerViewModel: не удалось создать хранилище состояния плеера")
        }

        // Очередь уведомляет ViewModel только после успешной синхронизации с SQLite.
        playlistManager.onTracksChanged = { [weak self] tracks in
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

        purchasedITunesAccessChangedObserver = NotificationCenter.default.addObserver(
            forName: .purchasedITunesMediaLibraryAccessDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.resumeLastTrackRestorationAfterPurchasedITunesAccessChange()
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

        eventObserver.onTrackBatchDidUpdate = { [weak self] events in
            self?.applyTrackUpdateEvents(events)
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
        refreshFavoriteTrackIds()
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
            let isFavorite = try favoritesService.isFavorite(
                trackId: currentTrack.trackId
            )
            updateFavoriteTrackState(
                trackId: currentTrack.trackId,
                isFavorite: isFavorite
            )
            isCurrentTrackFavorite = isFavorite
        } catch {
            // Ошибка чтения не должна оставлять состояние предыдущего трека в интерфейсной модели.
            isCurrentTrackFavorite = false
            PersistentLogger.log(
                "PlayerViewModel: ошибка проверки избранного trackId=\(currentTrack.trackId) error=\(error)"
            )
        }
    }

    /// Загружает исходный снимок «Избранного» для видимых строк до поступления точечных событий.
    private func refreshFavoriteTrackIds() {
        do {
            favoriteTrackIds = try favoritesService.loadFavoriteTrackIds()
        } catch {
            // Ошибка не должна оставлять в строках подтверждённое состояние предыдущего запуска.
            favoriteTrackIds = []
            PersistentLogger.log(
                "PlayerViewModel: ошибка загрузки избранного error=\(error)"
            )
        }
    }

    /// Точечно меняет published-снимок без повторного чтения всего системного треклиста.
    private func updateFavoriteTrackState(
        trackId: UUID,
        isFavorite: Bool
    ) {
        var updatedTrackIds = favoriteTrackIds

        if isFavorite {
            updatedTrackIds.insert(trackId)
        } else {
            updatedTrackIds.remove(trackId)
        }

        favoriteTrackIds = updatedTrackIds
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
                guard let self else {
                    return
                }

                self.updateFavoriteTrackState(
                    trackId: event.trackId,
                    isFavorite: event.isFavorite
                )

                guard event.trackId == self.currentTrackDisplayable?.trackId else {
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
        logPlayerStateDebug(
            "PLAYER STATE WRITE source=\(playbackSourceLogDescription(source)) " +
            "trackId=\(track.trackId) queueItemId=\(queueItemId?.uuidString ?? "nil") " +
            "position=0 duration=\(track.duration) " +
            "currentRuntimeTrackId=\(currentTrackDisplayable?.trackId.uuidString ?? "nil") " +
            "currentRuntimeSource=\(playbackSourceLogDescription(currentPlaybackContextSource))"
        )

        do {
            try statePersistence.saveCurrentTrack(
                trackId: track.trackId,
                queueItemId: queueItemId,
                duration: track.duration,
                playbackMode: playbackMode,
                contextSource: source
            )
            logPlayerStateDebug(
                "PLAYER STATE WRITE SUCCESS source=\(playbackSourceLogDescription(source)) " +
                "trackId=\(track.trackId) queueItemId=\(queueItemId?.uuidString ?? "nil")"
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

        logPlayerStateDebug(
            "PLAYER STATE READ \(playerStateLogDescription(state))"
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

        let savedDuration = state.duration.map { String($0) } ?? "nil"
        logPlayerStateDebug(
            "PLAYER STATE READ SOURCE source=\(playbackSourceLogDescription(source)) " +
            "trackId=\(trackId) queueItemId=\(state.currentQueueItemId?.uuidString ?? "nil") " +
            "position=\(state.playbackTime) duration=\(savedDuration)"
        )

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
            // Для UI достаточно записи реестра; контекст строится отдельной двухстадийной цепочкой.
            restoreLibraryTrackForDisplay(restorationIdentifier: restoration.identifier)
        case .purchasedITunes:
            restorePurchasedITunesPlaybackContext(restorationIdentifier: restoration.identifier)
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
        case .purchasedITunes:
            // iTunes использует отдельное событие MediaPlayer и не зависит от bookmark-доступа фонотеки.
            return
        }
    }

    /// Повторяет отложенное iTunes-восстановление только после нового результата системного запроса MediaPlayer.
    private func resumeLastTrackRestorationAfterPurchasedITunesAccessChange() {
        guard var restoration = pendingLastTrackRestoration,
              restoration.source == .purchasedITunes
        else {
            return
        }

        if restoration.isContextRestoreInFlight {
            // Готовность, пришедшая во время чтения, будет обработана после окончания именно этого запроса.
            restoration.shouldRetryPurchasedITunesContext = true
            pendingLastTrackRestoration = restoration
            return
        }

        restorePurchasedITunesPlaybackContext(restorationIdentifier: restoration.identifier)
    }

    /// Восстанавливает полный отсортированный контекст Purchased iTunes без обращения к очереди, фонотеке или экранной ViewModel.
    private func restorePurchasedITunesPlaybackContext(restorationIdentifier: UUID) {
        guard var restoration = pendingRestoration(with: restorationIdentifier),
              restoration.source == .purchasedITunes,
              restoration.isContextRestoreInFlight == false,
              currentTrackDisplayable == nil
        else {
            return
        }

        restoration.isContextRestoreInFlight = true
        restoration.shouldRetryPurchasedITunesContext = false
        pendingLastTrackRestoration = restoration
        // До полного результата сохраняем распознанный источник и не превращаем iTunes-состояние в очередь плеера.
        currentPlaybackContextSource = .purchasedITunes
        PersistentLogger.log(
            "Player restore purchased iTunes context started trackId=\(restoration.trackId)"
        )

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.finishContextRestoreAttempt(restorationIdentifier)

                if var updatedRestoration = self.pendingRestoration(with: restorationIdentifier),
                   updatedRestoration.shouldRetryPurchasedITunesContext {
                    updatedRestoration.shouldRetryPurchasedITunesContext = false
                    self.pendingLastTrackRestoration = updatedRestoration
                    self.restorePurchasedITunesPlaybackContext(restorationIdentifier: restorationIdentifier)
                }
            }

            let result = await self.purchasedITunesContextLoader.loadPlaybackContext()

            guard let activeRestoration = self.pendingRestoration(with: restorationIdentifier),
                  activeRestoration.source == .purchasedITunes,
                  self.currentTrackDisplayable == nil,
                  self.currentPlaybackContextSource == .purchasedITunes
            else {
                // Устаревший результат не может заменить новый выбор пользователя или его контекст.
                return
            }

            switch result {
            case .loaded(let tracks):
                guard let restoredTrack = tracks.first(where: {
                    $0.trackId == activeRestoration.trackId
                }) else {
                    self.confirmPendingTrackMissing(
                        restorationIdentifier,
                        reason: "currentTrackId отсутствует в актуальном Purchased iTunes-контексте " +
                            "trackId=\(activeRestoration.trackId)"
                    )
                    return
                }

                let context: [any TrackDisplayable] = tracks
                self.applyRestoredTrack(
                    restoredTrack,
                    context: context,
                    source: .purchasedITunes
                )
                self.completePendingRestoration(restorationIdentifier)

            case .temporarilyUnavailable:
                // Временная недоступность не доказывает удаление трека и оставляет сохранённое состояние до события MediaPlayer.
                PersistentLogger.log(
                    "Player restore purchased iTunes deferred: MediaPlayer временно недоступен " +
                        "trackId=\(activeRestoration.trackId)"
                )

            case .accessDenied:
                // Запрет доступа не является основанием подменять источник очередью или очищать сохранённый iTunes-трек.
                PersistentLogger.log(
                    "Player restore purchased iTunes deferred: доступ MediaPlayer запрещён " +
                        "trackId=\(activeRestoration.trackId)"
                )
            }
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

        // Сохранённое состояние без queueItemId восстанавливает только один трек.
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

            let stage: LibraryContextRestorationStage = self.isLibraryAccessRestored()
                ? .final
                : .preliminary
            self.restoreLibraryPlaybackContext(
                restorationIdentifier: restorationIdentifier,
                stage: stage
            )
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
        // Обложка и отсутствующие уточнения metadata будут запрошены только после final-стадии или при Play.
        updateMiniPlayerStaticState(for: displayTrack)
        updateMiniPlayerProgressState()
        PersistentLogger.log(
            "Player restore UI track applied trackId=\(displayTrack.trackId) " +
                "source=\(playbackSourceLogDescription(restoration.source))"
        )
    }

    /// Загружает локальный контекст воспроизведения из SQLite.
    /// Предварительная стадия разрешает навигацию до окончания синхронизации,
    /// окончательная — повторно проверяет порядок после libraryAccessRestored.
    private func restoreLibraryPlaybackContext(
        restorationIdentifier: UUID,
        stage: LibraryContextRestorationStage
    ) {
        guard var restoration = pendingRestoration(with: restorationIdentifier),
              restoration.source.isLibrarySource,
              restoration.isContextRestoreInFlight == false,
              currentTrackDisplayable?.trackId == restoration.trackId
        else {
            return
        }

        if case .final = stage,
           isLibraryAccessRestored() == false {
            return
        }

        if case .preliminary = stage,
           restoration.hasPreliminaryLibraryContext {
            return
        }

        let stageDescription: String
        switch stage {
        case .preliminary:
            stageDescription = "preliminary"
        case .final:
            stageDescription = "final"
        }

        restoration.isContextRestoreInFlight = true
        pendingLastTrackRestoration = restoration
        PersistentLogger.log(
            "Player restore library context started stage=\(stageDescription) source=" +
                "\(playbackSourceLogDescription(restoration.source)) trackId=\(restoration.trackId)"
        )

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.finishContextRestoreAttempt(restorationIdentifier)

                if case .preliminary = stage,
                   self.isLibraryAccessRestored() {
                    // Окончательная стадия не должна потеряться, если синхронизация завершилась во время SQLite-загрузки.
                    self.restoreLibraryPlaybackContext(
                        restorationIdentifier: restorationIdentifier,
                        stage: .final
                    )
                }
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
                        "Player restore library context has no current track stage=\(stageDescription) source=" +
                            "\(self.playbackSourceLogDescription(activeRestoration.source)) " +
                            "trackId=\(activeRestoration.trackId)"
                    )

                    if case .final = stage {
                        self.completePendingRestoration(restorationIdentifier)
                    }
                    return
                }

                self.applyRestoredLibraryPlaybackContext(
                    tracks,
                    restorationIdentifier: restorationIdentifier,
                    stage: stage
                )
            } catch {
                // Ошибка контекста не очищает ранний UI-трек: его существование подтверждает отдельный реестр.
                PersistentLogger.log(
                    "Player restore library context failed stage=\(stageDescription) source=" +
                        "\(self.playbackSourceLogDescription(activeRestoration.source)) error=\(error)"
                )

                if case .final = stage {
                    self.completePendingRestoration(restorationIdentifier)
                }
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
             .trackList,
             .purchasedITunes:
            return []
        }
    }

    /// Обновляет только playback-контекст; ранняя display-модель остаётся на месте без мигания мини-плеера.
    private func applyRestoredLibraryPlaybackContext(
        _ tracks: [LibraryTrack],
        restorationIdentifier: UUID,
        stage: LibraryContextRestorationStage
    ) {
        guard let restoration = pendingRestoration(with: restorationIdentifier),
              let currentTrack = currentTrackDisplayable,
              currentTrack.trackId == restoration.trackId
        else {
            return
        }

        let context: [any TrackDisplayable] = tracks
        let sourceDescription = playbackSourceLogDescription(restoration.source)
        let currentTrackId = currentTrack.trackId
        currentPlaybackContextSource = restoration.source
        currentContext = PlaybackContext.detect(from: context)
        _ = playbackContextStore.updateContext(
            currentTrack: currentTrack,
            context: context
        )
        setPlaybackContextReady(true)

        let stageDescription: String
        switch stage {
        case .preliminary:
            var updatedRestoration = restoration
            updatedRestoration.hasPreliminaryLibraryContext = true
            pendingLastTrackRestoration = updatedRestoration
            stageDescription = "preliminary"
        case .final:
            // После синхронизации bookmark-доступ уже восстановлен, поэтому вторичные runtime-данные можно догрузить отдельно от UI.
            requestSnapshotIfNeeded(for: currentTrack)
            stageDescription = "final"
            completePendingRestoration(restorationIdentifier)
        }

        updateMiniPlayerProgressState()
        PersistentLogger.log(
            "Player restore library context completed stage=\(stageDescription) source=" +
                "\(sourceDescription) trackId=\(currentTrackId) contextCount=\(context.count)"
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

            if restoredTrack.isPurchasedITunesRuntimeTrack {
                // Старые версии записывали прямой iTunes-запуск как playerQueue; после распознавания нельзя оставлять одиночный fallback-контекст.
                activeRestoration.source = .purchasedITunes
                self.pendingLastTrackRestoration = activeRestoration
                self.restorePurchasedITunesPlaybackContext(restorationIdentifier: restorationIdentifier)
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
        logPlayerStateDebug(
            "RESTORE APPLY restorationType=\(playbackSourceLogDescription(source)) " +
            "restorationIdentifier=\(pendingLastTrackRestoration?.identifier.uuidString ?? "nil") " +
            "savedSource=\(playbackSourceLogDescription(pendingLastTrackRestoration?.source ?? source)) " +
            "savedTrackId=\(pendingLastTrackRestoration?.trackId.uuidString ?? "nil") " +
            "appliedTrackId=\(track.trackId) " +
            "appliedTrackSource=\(playbackSourceLogDescription(source)) contextCount=\(context.count)"
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
        case .purchasedITunes:
            return "purchasedITunes"
        }
    }

    /// Записывает подробную диагностику восстановления только в DEBUG-сборках.
    private func logPlayerStateDebug(_ message: @autoclosure () -> String) {
        #if DEBUG
        PersistentLogger.log(message())
        #endif
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
    
    // MARK: - Снимок

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
        applyTrackUpdateEvents([updateEvent])
    }

    /// Применяет batch snapshot-ов до одной публикации runtime presentation плеера.
    private func applyTrackUpdateEvents(_ updateEvents: [TrackUpdateEvent]) {
        let changedTrackIds = runtimeSnapshotController.applyTrackUpdateEvents(updateEvents)
        guard !changedTrackIds.isEmpty else {
            return
        }

        publishRuntimeSnapshots()

        if let current = currentTrackDisplayable,
           changedTrackIds.contains(current.trackId) {
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
    
    // MARK: - Обновления состояния MiniPlayer

    /// Пересобирает статическое состояние мини-плеера из текущего трека и runtime snapshot.
    private func updateMiniPlayerStaticState(for track: any TrackDisplayable) {
        let snapshot = runtimeSnapshotController.snapshot(for: track.trackId)
        miniPlayerStaticState = MiniPlayerStateBuilder.buildStaticState(
            track: track,
            snapshot: snapshot,
            isTagReadingEnabled: isTagReadingEnabled()
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
        let requestID = preparedLocalFile.requestID

        guard currentTrackDisplayable?.trackId == trackId,
              isCurrentPlaybackRequest(requestID)
        else {
            // Поздний сигнал прежнего request не должен отменять уже начатую задачу нового selection с тем же trackId.
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
                      self.currentTrackDisplayable?.trackId == trackId,
                      self.isCurrentPlaybackRequest(requestID)
                else {
                    // Результат старого request нельзя публиковать после быстрой смены selection или повторного запуска того же трека.
                    return
                }

                self.waveformState = .ready(samples)
            } catch is CancellationError {
                // Отмена штатна при смене текущего трека и не является ошибкой playback.
            } catch {
                guard !Task.isCancelled,
                      let self,
                      self.currentTrackDisplayable?.trackId == trackId,
                      self.isCurrentPlaybackRequest(requestID)
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
        play(
            track: track,
            context: context,
            source: source,
            changeReason: .passive
        )
    }

    /// Выполняет смену трека с семантикой источника, не расширяя общий playback capability для внешних feature.
    private func play(
        track: any TrackDisplayable,
        context: [any TrackDisplayable],
        source: PlaybackContextSource,
        changeReason: ActiveTrackChangeReason
    ) {
        
        // Определяем контекст воспроизведения
        let contextType = PlaybackContext.detect(from: context)
        let resolvedSource = playbackContextSource(
            for: context,
            contextType: contextType,
            requestedSource: source
        )
        let isSameContext = playbackContextStore.isCurrentContext(context)
        let isSameTrack: Bool
        if let current = currentTrackDisplayable {
            isSameTrack = current.id == track.id &&
                type(of: current) == type(of: track) &&
                currentContext == contextType &&
                isSameContext &&
                currentPlaybackContextSource == resolvedSource
        } else {
            isSameTrack = false
        }

        currentContext = contextType
        currentPlaybackContextSource = resolvedSource

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
        invalidateCurrentPlaybackRequest()
        playerManager.stopAccessingCurrentTrack()
        resetWaveformState()
        logPlayerStateDebug(
            "CURRENT TRACK REPLACED oldTrackId=\(currentTrackDisplayable?.trackId.uuidString ?? "nil") " +
            "oldSource=\(playbackSourceLogDescription(currentPlaybackContextSource)) " +
            "newTrackId=\(track.trackId) " +
            "newSource=\(playbackSourceLogDescription(resolvedSource)) caller=userPlay"
        )
        currentTrackDisplayable = track
        publishAutomaticListScrollTriggerIfNeeded(
            reason: changeReason,
            track: track,
            context: contextType
        )
        setPlaybackContextReady(hasConfirmedPlaybackContext)
        miniPlayerStaticState = nil
        currentTime = 0
        trackDuration = 0
        isCurrentTrackPreparedForPlayback = false
        persistCurrentTrack(track, source: resolvedSource)
        requestSnapshotIfNeeded(for: track)
        
        updateMiniPlayerStaticState(for: track)
        updateMiniPlayerProgressState()
        
        startPlaybackPreparation(for: track)

    }

    /// Возвращает трек, который должен попасть непосредственно в PlayerManager.
    private func playbackTrack(
        for track: any TrackDisplayable
    ) -> any TrackDisplayable {
        track.asPurchasedITunesPlayableTrack() ?? track
    }

    /// Запускает общий request-flow для пользовательского и восстановленного Play, сохраняя identity PlayerManager на всех UI границах.
    private func startPlaybackPreparation(for track: any TrackDisplayable) {
        playbackTask?.cancel()
        let requestID = playerManager.beginPlaybackRequest()
        activePlaybackRequestID = requestID
        isPreparingCurrentTrackForPlayback = true

        // Для iTunes-источника передаём в PlayerManager адаптер с assetURL,
        // а currentTrackDisplayable оставляем исходным для подсветки контекста.
        let playbackTrack = playbackTrack(for: track)
        let playerManager = playerManager
        playbackTask = Task { @MainActor [weak self, playerManager] in
            defer {
                if let self,
                   self.isCurrentPlaybackRequest(requestID) {
                    // Только текущий request снимает флаг подготовки и освобождает свою task-reference.
                    self.isPreparingCurrentTrackForPlayback = false
                    self.playbackTask = nil
                }
            }

            do {
                let result = try await playerManager.play(
                    requestID: requestID,
                    track: playbackTrack,
                    onPreparedLocalFile: { [weak self] preparedLocalFile in
                        // ViewModel запускает waveform до получения duration; PlayerManager не знает о кэше и генераторе.
                        guard self?.isCurrentPlaybackRequest(requestID) == true else {
                            return
                        }
                        self?.loadWaveformIfPossible(for: preparedLocalFile)
                    }
                )
                guard result == .started,
                      let self,
                      self.isCurrentPlaybackRequest(requestID)
                else {
                    return
                }

                self.isCurrentTrackPreparedForPlayback = true
                self.isPlaying = true
                self.updateMiniPlayerProgressState()
                // Первичное заполнение Now Playing Info (duration ещё может быть 0).
                self.playerManager.applyNowPlaying(snapshot: self.makeNowPlayingSnapshot(for: track))
                self.startObservingProgress()
            } catch let appError as AppError {
                guard let self,
                      self.isCurrentPlaybackRequest(requestID)
                else {
                    return
                }

                self.isCurrentTrackPreparedForPlayback = false
                self.isPlaying = false
                self.updateMiniPlayerProgressState()
                self.toastPresenter.handle(appError)
            } catch {
                guard let self,
                      self.isCurrentPlaybackRequest(requestID)
                else {
                    return
                }

                self.isCurrentTrackPreparedForPlayback = false
                self.isPlaying = false
                self.updateMiniPlayerProgressState()
                self.toastPresenter.handle(.playbackFailed(title: track.title ?? track.fileName))
            }
        }
    }

    /// Проверяет UI-связь только с identity, которой владеет PlayerManager, не создавая параллельный request-state.
    private func isCurrentPlaybackRequest(_ requestID: PlaybackRequestID) -> Bool {
        activePlaybackRequestID == requestID && playerManager.isCurrentPlaybackRequest(requestID)
    }

    /// Отменяет preparation и инвалидирует только её identity перед новым выбором, file operation или deinit.
    private func invalidateCurrentPlaybackRequest() {
        playbackTask?.cancel()
        playbackTask = nil

        guard let activePlaybackRequestID else {
            return
        }

        playerManager.invalidatePlaybackRequest(activePlaybackRequestID)
        self.activePlaybackRequestID = nil
    }

    /// Определяет постоянный источник по общему контексту, сохраняя явный источник очереди для любых иных runtime-моделей.
    private func playbackContextSource(
        for context: [any TrackDisplayable],
        contextType: PlaybackContext,
        requestedSource: PlaybackContextSource
    ) -> PlaybackContextSource {
        guard contextType == .purchasedITunes,
              context.isEmpty == false,
              context.allSatisfy({ $0.isPurchasedITunesRuntimeTrack })
        else {
            return requestedSource
        }

        return .purchasedITunes
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

        // Восстановленный запуск использует тот же request-flow, что и явный выбор пользователя.
        startPlaybackPreparation(for: track)
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

        favoriteActionHandler.toggle(
            FavoriteTrackInput(playerTrack: currentTrack)
        )
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

    /// Останавливает playback и освобождает файл, сохраняя published-состояние плеера согласованным.
    /// Используется только перед подтверждёнными файловыми операциями внешних feature.
    func releaseCurrentPlaybackFile() {
        invalidateCurrentPlaybackRequest()
        playerManager.releaseCurrentTrackForFileOperation()
        isPlaying = false
        isCurrentTrackPreparedForPlayback = false
        isPreparingCurrentTrackForPlayback = false
        applyCurrentPlaybackState()
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
    func playNextTrack(
        reason: ActiveTrackChangeReason = .passive
    ) {
        guard isPlaybackContextReady,
              canPlayNextTrack else {
            return
        }

        _ = startNextTrack(reason: reason)
    }

    /// Запускает следующий трек и сообщает, был ли найден переход.
    @discardableResult
    private func startNextTrack(
        reason: ActiveTrackChangeReason = .passive
    ) -> Bool {
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
                source: currentPlaybackContextSource,
                changeReason: reason
            )
        }
        return true
    }
    
    /// Предыдущий трек в текущем контексте
    func playPreviousTrack(
        reason: ActiveTrackChangeReason = .passive
    ) {
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
            source: currentPlaybackContextSource,
            changeReason: reason
        )
    }

    /// Публикует одноразовый scroll intent только после смены displayable-строки из MiniPlayer.
    private func publishAutomaticListScrollTriggerIfNeeded(
        reason: ActiveTrackChangeReason,
        track: any TrackDisplayable,
        context: PlaybackContext
    ) {
        activeTrackChangeReason = reason

        guard reason.requestsMatchingListCentering else {
            return
        }

        automaticListScrollTrigger = AutomaticListScrollTrigger(
            id: UUID(),
            targetDisplayableId: track.id,
            targetContext: context
        )
    }
    
    
    // MARK: - Проверка "текущего" трека
    
    func isCurrent(_ track: any TrackDisplayable, in context: PlaybackContext) -> Bool {
        guard let current = currentTrackDisplayable,
              let currentCtx = currentContext else { return false }
        
        return current.id == track.id && currentCtx == context
    }
    
    
    
    // MARK: - Деинициализация
    
    isolated deinit {
        waveformTask?.cancel()
        playbackTask?.cancel()
        if let libraryAccessRestoredObserver {
            NotificationCenter.default.removeObserver(libraryAccessRestoredObserver)
        }
        if let purchasedITunesAccessChangedObserver {
            NotificationCenter.default.removeObserver(purchasedITunesAccessChangedObserver)
        }
        if let activePlaybackRequestID {
            playerManager.invalidatePlaybackRequest(activePlaybackRequestID)
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
             .trackList,
             .purchasedITunes:
            return false
        }
    }
}
