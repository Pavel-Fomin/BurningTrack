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
    /// Изолирует постоянное состояние выбранного трека от playback- и UI-логики.
    private let statePersistence: (any PlayerStatePersisting)?
    /// Очередь используется для восстановления PlayerTrack и проверки удаления текущего элемента.
    private let playlistManager: PlaylistManager
    /// Загружает актуальные списки фонотеки без переноса SQLite-логики в PlayerViewModel.
    private let libraryContextLoader: any LibraryPlaybackContextLoading
    /// Показывает, что текущий трек восстановлен для интерфейса, но ещё не загружен в PlayerManager.
    private var isCurrentTrackPreparedForPlayback = false
    /// Источник текущего playback-контекста нужен для сохранения его при переходе Next/Previous.
    private var currentPlaybackContextSource: PlaybackContextSource = .playerQueue
    /// Не даёт повторно очищать состояние до завершения восстановления доступа к фонотеке.
    private var didReceiveLibraryAccessRestored = false
    /// Наблюдатель нужен для повторной попытки восстановления локального трека после открытия bookmark-доступа.
    private var libraryAccessRestoredObserver: NSObjectProtocol?

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
        toastPresenter: (any ToastPresenting)? = nil,
        statePersistence: (any PlayerStatePersisting)? = nil,
        playlistManager: PlaylistManager? = nil,
        libraryContextLoader: (any LibraryPlaybackContextLoading)? = nil
    ) {
        let resolvedPlaylistManager = playlistManager ?? PlaylistManager.shared

        self.playerManager = playerManager
        // Store создаётся внутри main-actor и синхронно восстанавливает режим до первого контекста.
        self.playbackContextStore = playbackContextStore ?? PlayerPlaybackContextStore()
        self.nowPlayingSnapshotBuilder = nowPlayingSnapshotBuilder
        self.runtimeSnapshotController = runtimeSnapshotController
        self.eventObserver = eventObserver
        self.toastPresenter = toastPresenter ?? ToastManager.shared
        self.statePersistence = statePersistence ?? (try? PlayerStatePersistence())
        self.playlistManager = resolvedPlaylistManager
        self.libraryContextLoader = libraryContextLoader ?? LibraryPlaybackContextLoader()
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
                self.didReceiveLibraryAccessRestored = true
                self.restoreLastTrack()
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

        // Восстановление только подготавливает состояние мини-плеера и не запускает AVPlayer.
        restoreLastTrack()
    }

    // MARK: - Состояние выбранного трека

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

    /// Загружает состояние и восстанавливает последний трек без запуска playback.
    private func restoreLastTrack() {
        guard currentTrackDisplayable == nil,
              let statePersistence
        else {
            return
        }

        let state: PlayerStateDatabaseModel?
        do {
            state = try statePersistence.loadState()
        } catch {
            PersistentLogger.log(
                "PlayerViewModel: невалидное или недоступное состояние плеера: \(error)"
            )
            // Повреждённое состояние не должно оставлять старую запись для повторной ошибки на каждом запуске.
            clearPersistedState(reason: stateLoadClearReason(for: error))
            return
        }

        guard let state else {
            PersistentLogger.log("Player state load: empty")
            return
        }

        PersistentLogger.log(
            "Player state load: \(playerStateLogDescription(state))"
        )

        guard let trackId = state.currentTrackId else {
            if state.contextType == .libraryCollection {
                PersistentLogger.log(
                    "Player restore library collection has no current track"
                )
                clearPersistedState(reason: "отсутствует currentTrackId для libraryCollection")
            }
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
            // Невалидный источник не должен повторно приводить к ошибке на следующем запуске.
            if state.contextType == .trackList || state.contextType == .libraryCollection {
                clearPersistedState(
                    reason: "невалидные обязательные поля playback-контекста " +
                        "contextType=\(state.contextType.rawValue)"
                )
            }
            return
        }

        switch source {
        case .playerQueue:
            restoreQueueContext(state: state, trackId: trackId)
        case .trackList(let trackListId):
            restoreTrackListContext(trackListId: trackListId, trackId: trackId)
        case .libraryFolder,
             .libraryRoot,
             .libraryCollection:
            // Источник фонотеки нельзя считать пустым до завершения восстановления доступа.
            guard MusicLibraryManager.shared.isAccessRestored else {
                PersistentLogger.log(
                    "Player restore deferred: библиотека ещё не готова " +
                    "source=\(playbackSourceLogDescription(source))"
                )
                return
            }
            restoreLibraryContext(source: source, trackId: trackId)
        }
    }

    /// Восстанавливает очередь или сохраняет прежний fallback для состояния без queueItemId.
    private func restoreQueueContext(
        state: PlayerStateDatabaseModel,
        trackId: UUID
    ) {
        // Элемент очереди восстанавливается первым, так как queueItemId различает повторные вхождения одного trackId.
        if let queueItemId = state.currentQueueItemId,
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
            return
        }

        if let queueItemId = state.currentQueueItemId {
            PersistentLogger.log(
                "Player restore queue item not found: " +
                "queueItemId=\(queueItemId) trackId=\(trackId) " +
                "queueCount=\(playlistManager.tracks.count); using trackId fallback"
            )
        } else {
            PersistentLogger.log(
                "Player restore queue item id missing: " +
                "trackId=\(trackId); using trackId fallback"
            )
        }

        // Legacy-состояния без queueItemId сохраняют прежнее восстановление одиночного трека.
        restoreFallbackTrack(trackId: trackId, duration: state.duration)
    }

    /// Восстанавливает актуальный состав треклиста из SQLite без сохранения массива в player_state.
    private func restoreTrackListContext(
        trackListId: UUID,
        trackId: UUID
    ) {
        Task { @MainActor [weak self] in
            guard let self, self.currentTrackDisplayable == nil else {
                return
            }

            do {
                let trackList = try TrackListManager.shared.getTrackListById(trackListId)
                guard let restoredTrack = trackList.tracks.first(where: { $0.trackId == trackId }) else {
                    PersistentLogger.log(
                        "Player restore trackList track not found listId=\(trackListId) trackId=\(trackId)"
                    )
                    self.clearPersistedState(
                        reason: "currentTrackId отсутствует в восстановленном треклисте " +
                            "listId=\(trackListId) trackId=\(trackId)"
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
            } catch {
                PersistentLogger.log(
                    "Player restore trackList failed listId=\(trackListId) error=\(error)"
                )
                self.clearPersistedState(
                    reason: "треклист не найден или не загрузился listId=\(trackListId) error=\(error)"
                )
            }
        }
    }

    /// Восстанавливает папочный или корневой контекст фонотеки через общий loader.
    private func restoreLibraryContext(
        source: PlaybackContextSource,
        trackId: UUID
    ) {
        Task { @MainActor [weak self] in
            guard let self, self.currentTrackDisplayable == nil else {
                return
            }

            do {
                let tracks: [LibraryTrack]
                switch source {
                case .libraryFolder(let folderId):
                    tracks = try await self.libraryContextLoader.loadFolderContext(
                        folderId: folderId
                    )
                case .libraryRoot:
                    tracks = try await self.libraryContextLoader.loadRootContext()
                case .libraryCollection(
                    let category,
                    let rawValue,
                    let artistKey
                ):
                    tracks = try await self.libraryContextLoader.loadCollectionContext(
                        category: category,
                        rawValue: rawValue,
                        artistKey: artistKey
                    )
                case .playerQueue,
                     .trackList:
                    return
                }

                guard let restoredTrack = tracks.first(where: { $0.trackId == trackId }) else {
                    PersistentLogger.log(
                        "Player restore library track not found source=\(source) trackId=\(trackId)"
                    )
                    self.clearPersistedState(
                        reason: "currentTrackId отсутствует в восстановленном списке " +
                            "source=\(self.playbackSourceLogDescription(source)) trackId=\(trackId)"
                    )
                    return
                }

                let context: [any TrackDisplayable] = tracks
                PersistentLogger.log(
                    "Player restore library source=\(source) " +
                    "trackId=\(restoredTrack.trackId) trackCount=\(context.count)"
                )
                self.applyRestoredTrack(
                    restoredTrack,
                    context: context,
                    source: source
                )
            } catch {
                PersistentLogger.log(
                    "Player restore library context failed source=\(source) error=\(error)"
                )
                let reason: String
                switch source {
                case .libraryFolder:
                    reason = "папка не найдена или не загрузилась source=\(self.playbackSourceLogDescription(source)) error=\(error)"
                case .libraryRoot:
                    reason = "корень фонотеки не загрузился source=\(self.playbackSourceLogDescription(source)) error=\(error)"
                case .libraryCollection:
                    reason = "категория не найдена или не загрузилась source=\(self.playbackSourceLogDescription(source)) error=\(error)"
                case .playerQueue,
                     .trackList:
                    reason = "неожиданный источник library-восстановления source=\(self.playbackSourceLogDescription(source)) error=\(error)"
                }
                self.clearPersistedState(reason: reason)
            }
        }
    }

    /// Восстанавливает одиночный display-трек для старого состояния без контекста списка.
    private func restoreFallbackTrack(
        trackId: UUID,
        duration: TimeInterval?
    ) {
        Task { @MainActor [weak self] in
            guard let self, self.currentTrackDisplayable == nil else {
                return
            }

            guard let restoredTrack = await self.restoreTrack(
                trackId: trackId,
                duration: duration
            ) else {
                guard self.currentTrackDisplayable == nil else {
                    return
                }

                guard self.didReceiveLibraryAccessRestored else {
                    PersistentLogger.log(
                        "Player restore deferred: fallback track unavailable before " +
                        "libraryAccessRestored trackId=\(trackId)"
                    )
                    return
                }

                self.clearPersistedState(
                    reason: "трек не найден после восстановления доступа trackId=\(trackId)"
                )
                return
            }

            self.applyRestoredTrack(
                restoredTrack,
                context: [restoredTrack],
                source: .playerQueue
            )
        }
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
        isCurrentTrackPreparedForPlayback = false
        currentTime = 0
        trackDuration = track.duration
        isPlaying = false
        miniPlayerStaticState = nil
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
        currentTrackDisplayable = nil
        currentContext = nil
        currentPlaybackContextSource = .playerQueue
        currentTime = 0
        trackDuration = 0
        isPlaying = false
        isCurrentTrackPreparedForPlayback = false
        miniPlayerStaticState = nil
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

        // Если это тот же уже загруженный трек и тот же контекст — просто продолжить.
        if isSameTrack && isCurrentTrackPreparedForPlayback {
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
        isCurrentTrackPreparedForPlayback = false
        persistCurrentTrack(track, source: source)
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
            let now = CACurrentMediaTime()
            // UI прогресс: ~20 Hz.
            if now - self.lastMiniPlayerTick >= 1.0 {
                self.lastMiniPlayerTick = now
                self.updateMiniPlayerProgressState()
            }
            // Now Playing: 1 Hz.
            if now - self.lastNowPlayingTick >= 1.0 {
                self.lastNowPlayingTick = now
                self.playerManager.applyPlaybackTime(currentTime: time, isPlaying: self.isPlaying)
            }
        }
    }

    /// Загружает восстановленный трек в PlayerManager только после первого нажатия Play.
    private func prepareAndPlayRestoredTrack(_ track: any TrackDisplayable) {
        Task { @MainActor in
            do {
                let playbackTrack = playbackTrack(for: track)
                try await playerManager.play(track: playbackTrack)
                isCurrentTrackPreparedForPlayback = true
                isPlaying = true
                updateMiniPlayerProgressState()
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
                toastPresenter.handle(
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
        guard let current = currentTrackDisplayable else { return }
        guard playbackContextStore.hasMultipleTracks else { return }
        
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
        if let libraryAccessRestoredObserver {
            NotificationCenter.default.removeObserver(libraryAccessRestoredObserver)
        }
        playerManager.removeTimeObserver()
    }
}
