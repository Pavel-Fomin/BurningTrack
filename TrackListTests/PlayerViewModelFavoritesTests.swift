//
//  PlayerViewModelFavoritesTests.swift
//  TrackList
//
//  Проверки состояния «Избранного» для текущего трека PlayerViewModel.
//
//  Created by Pavel Fomin on 30.07.2026.
//

import Combine
import Foundation
import MediaPlayer
import XCTest
@testable import TrackList

@MainActor
final class PlayerViewModelFavoritesTests: XCTestCase {

    /// Отсутствие текущего трека не запускает мутацию и оставляет состояние ложным.
    func testNoCurrentTrackKeepsFavoritesStateFalseAndDoesNotToggle() {
        let service = PlayerFavoritesServiceSpy()
        let viewModel = makeViewModel(favoritesService: service)

        XCTAssertFalse(viewModel.isCurrentTrackFavorite)
        viewModel.toggleCurrentTrackFavorite()

        XCTAssertEqual(service.toggleInputs, [])
    }

    /// Пустой плеер отключает системную команду и не помечает её активной.
    func testFavoriteRemoteCommandIsDisabledWithoutCurrentTrack() {
        let playerManager = PlayerFavoritesPlayerManagerSpy()
        _ = makeViewModel(
            favoritesService: PlayerFavoritesServiceSpy(),
            playerManager: playerManager
        )

        XCTAssertEqual(playerManager.favoriteCommandSetupCount, 1)
        XCTAssertEqual(
            playerManager.favoriteCommandStates.last,
            PlayerFavoritesPlayerManagerSpy.FavoriteCommandState(
                isEnabled: false,
                isActive: false
            )
        )
    }

    /// Локальный трек использует канонический UUID из tracks.id при первичной проверке.
    func testLocalTrackReadsFavoritesStateByCanonicalTrackId() {
        let track = makeLocalTrack()
        let service = PlayerFavoritesServiceSpy(favoriteTrackIds: [])
        let viewModel = makeViewModel(favoritesService: service)

        viewModel.play(track: track)

        XCTAssertFalse(viewModel.isCurrentTrackFavorite)
        XCTAssertEqual(service.requestedFavoriteTrackIds, [track.trackId])
    }

    /// Локальный трек, присутствующий в сервисе, сразу публикует истинное состояние ViewModel.
    func testFavoriteLocalTrackPublishesTrueState() {
        let track = makeLocalTrack()
        let service = PlayerFavoritesServiceSpy(favoriteTrackIds: [track.trackId])
        let viewModel = makeViewModel(favoritesService: service)

        viewModel.play(track: track)

        XCTAssertTrue(viewModel.isCurrentTrackFavorite)
    }

    /// iTunes-трек проверяется по устойчивому внешнему UUID и сохраняет assetURL в будущем входе сервиса.
    func testPurchasedITunesTrackUsesStableIdentifier() {
        let track = makePurchasedITunesTrack()
        let service = PlayerFavoritesServiceSpy(favoriteTrackIds: [track.trackId])
        let viewModel = makeViewModel(favoritesService: service)

        viewModel.play(track: track)

        XCTAssertTrue(viewModel.isCurrentTrackFavorite)
        XCTAssertEqual(service.requestedFavoriteTrackIds, [track.trackId])
    }

    /// Смена currentTrackDisplayable пересчитывает состояние только для нового логического trackId.
    func testChangingCurrentTrackRefreshesFavoritesState() {
        let first = makeLocalTrack()
        let second = makeLocalTrack()
        let service = PlayerFavoritesServiceSpy(favoriteTrackIds: [first.trackId])
        let viewModel = makeViewModel(favoritesService: service)

        viewModel.play(track: first)
        XCTAssertTrue(viewModel.isCurrentTrackFavorite)

        viewModel.play(track: second)
        XCTAssertFalse(viewModel.isCurrentTrackFavorite)

        service.favoriteTrackIds = [second.trackId]
        viewModel.play(track: first)
        XCTAssertFalse(viewModel.isCurrentTrackFavorite)

        viewModel.play(track: second)
        XCTAssertTrue(viewModel.isCurrentTrackFavorite)
    }

    /// Смена текущего трека синхронизирует системный индикатор с новым состоянием «Избранного».
    func testChangingCurrentTrackUpdatesFavoriteRemoteCommandState() {
        let favoriteTrack = makeLocalTrack()
        let regularTrack = makeLocalTrack()
        let service = PlayerFavoritesServiceSpy(favoriteTrackIds: [favoriteTrack.trackId])
        let playerManager = PlayerFavoritesPlayerManagerSpy()
        let viewModel = makeViewModel(
            favoritesService: service,
            playerManager: playerManager
        )

        viewModel.play(track: favoriteTrack)
        XCTAssertEqual(
            playerManager.favoriteCommandStates.last,
            PlayerFavoritesPlayerManagerSpy.FavoriteCommandState(
                isEnabled: true,
                isActive: true
            )
        )

        viewModel.play(track: regularTrack)
        XCTAssertEqual(
            playerManager.favoriteCommandStates.last,
            PlayerFavoritesPlayerManagerSpy.FavoriteCommandState(
                isEnabled: true,
                isActive: false
            )
        )
    }

    /// Очистка очереди сбрасывает состояние вместе с currentTrackDisplayable.
    func testClearingCurrentPlayerTrackResetsFavoritesState() {
        let track = makeLocalTrack()
        let service = PlayerFavoritesServiceSpy(favoriteTrackIds: [track.trackId])
        let harness = makeHarness(favoritesService: service)
        harness.playlistManager.tracks = [track]

        harness.viewModel.play(track: track)
        XCTAssertTrue(harness.viewModel.isCurrentTrackFavorite)

        XCTAssertTrue(harness.playlistManager.clear())

        XCTAssertNil(harness.viewModel.currentTrackDisplayable)
        XCTAssertFalse(harness.viewModel.isCurrentTrackFavorite)
    }

    /// Точечное событие обновляет published-снимок и не инициирует повторное чтение сервиса.
    func testFavoritesEventUpdatesPublishedStateAndCurrentTrack() {
        let currentTrack = makeLocalTrack()
        let anotherTrack = makeLocalTrack()
        let service = PlayerFavoritesServiceSpy(favoriteTrackIds: [])
        let events = PlayerFavoritesEventsSubject()
        let viewModel = makeViewModel(
            favoritesService: service,
            favoritesEvents: events
        )

        viewModel.play(track: currentTrack)
        let readsBeforeEvents = service.requestedFavoriteTrackIds.count

        events.send(
            FavoritesChangeEvent(trackId: anotherTrack.trackId, isFavorite: true)
        )
        XCTAssertFalse(viewModel.isCurrentTrackFavorite)
        XCTAssertTrue(viewModel.favoriteTrackIds.contains(anotherTrack.trackId))

        events.send(
            FavoritesChangeEvent(trackId: currentTrack.trackId, isFavorite: true)
        )
        XCTAssertTrue(viewModel.isCurrentTrackFavorite)

        events.send(
            FavoritesChangeEvent(trackId: currentTrack.trackId, isFavorite: false)
        )
        XCTAssertFalse(viewModel.isCurrentTrackFavorite)
        XCTAssertEqual(service.requestedFavoriteTrackIds.count, readsBeforeEvents)
    }

    /// Событие текущего трека меняет системный индикатор, а событие другого трека его не затрагивает.
    func testFavoritesEventUpdatesOnlyCurrentFavoriteRemoteCommandState() {
        let currentTrack = makeLocalTrack()
        let anotherTrack = makeLocalTrack()
        let events = PlayerFavoritesEventsSubject()
        let playerManager = PlayerFavoritesPlayerManagerSpy()
        let viewModel = makeViewModel(
            favoritesService: PlayerFavoritesServiceSpy(),
            favoritesEvents: events,
            playerManager: playerManager
        )

        viewModel.play(track: currentTrack)
        let statesBeforeAnotherTrackEvent = playerManager.favoriteCommandStates
        events.send(FavoritesChangeEvent(trackId: anotherTrack.trackId, isFavorite: true))
        XCTAssertEqual(playerManager.favoriteCommandStates, statesBeforeAnotherTrackEvent)

        events.send(FavoritesChangeEvent(trackId: currentTrack.trackId, isFavorite: true))
        XCTAssertEqual(
            playerManager.favoriteCommandStates.last,
            PlayerFavoritesPlayerManagerSpy.FavoriteCommandState(
                isEnabled: true,
                isActive: true
            )
        )
    }

    /// Событие при пустом плеере обновляет строки и не меняет ложное состояние текущего трека.
    func testFavoritesEventUpdatesRowsWithoutCurrentTrack() {
        let events = PlayerFavoritesEventsSubject()
        let viewModel = makeViewModel(
            favoritesService: PlayerFavoritesServiceSpy(),
            favoritesEvents: events
        )

        events.send(FavoritesChangeEvent(trackId: UUID(), isFavorite: true))

        XCTAssertFalse(viewModel.isCurrentTrackFavorite)
        XCTAssertEqual(viewModel.favoriteTrackIds.count, 1)
    }

    /// Toggle передаёт полный snapshot текущего iTunes-трека и ожидает событие вместо оптимистического изменения.
    func testTogglePassesCurrentTrackSnapshotAndWaitsForEvent() {
        let track = makePurchasedITunesTrack()
        let service = PlayerFavoritesServiceSpy(favoriteTrackIds: [])
        let events = PlayerFavoritesEventsSubject()
        let viewModel = makeViewModel(
            favoritesService: service,
            favoritesEvents: events
        )

        viewModel.play(track: track)
        viewModel.toggleCurrentTrackFavorite()

        XCTAssertEqual(service.toggleInputs.count, 1)
        XCTAssertEqual(service.toggleInputs.first?.trackId, track.trackId)
        XCTAssertEqual(service.toggleInputs.first?.title, track.title)
        XCTAssertEqual(service.toggleInputs.first?.artist, track.artist)
        XCTAssertEqual(service.toggleInputs.first?.album, track.album)
        XCTAssertEqual(service.toggleInputs.first?.artworkData, track.artworkData)
        XCTAssertEqual(service.toggleInputs.first?.source, .purchasedITunes)
        XCTAssertEqual(service.toggleInputs.first?.assetURL, track.assetURL)
        XCTAssertFalse(viewModel.isCurrentTrackFavorite)

        events.send(FavoritesChangeEvent(trackId: track.trackId, isFavorite: true))
        XCTAssertTrue(viewModel.isCurrentTrackFavorite)
    }

    /// Ошибка сервиса не меняет уже известное состояние и не создаёт ложное событие.
    func testToggleErrorPreservesCurrentFavoritesState() {
        let track = makeLocalTrack()
        let service = PlayerFavoritesServiceSpy(favoriteTrackIds: [track.trackId])
        service.toggleError = PlayerFavoritesTestError.toggleFailed
        let viewModel = makeViewModel(favoritesService: service)

        viewModel.play(track: track)
        viewModel.toggleCurrentTrackFavorite()

        XCTAssertTrue(viewModel.isCurrentTrackFavorite)
        XCTAssertEqual(service.toggleInputs.count, 1)
    }

    /// Системная команда применяет её итоговое состояние к актуальному, а не захваченному при регистрации треку.
    func testFavoriteRemoteCommandUsesCurrentTrackAndDesiredState() {
        let firstTrack = makeLocalTrack()
        let currentTrack = makeLocalTrack()
        let service = PlayerFavoritesServiceSpy()
        let playerManager = PlayerFavoritesPlayerManagerSpy()
        let viewModel = makeViewModel(
            favoritesService: service,
            playerManager: playerManager
        )

        viewModel.play(track: firstTrack)
        viewModel.play(track: currentTrack)

        XCTAssertEqual(playerManager.triggerFavoriteCommand(isFavorite: true), .success)
        XCTAssertEqual(service.addInputs.map(\.trackId), [currentTrack.trackId])
        XCTAssertFalse(viewModel.isCurrentTrackFavorite)

        XCTAssertEqual(playerManager.triggerFavoriteCommand(isFavorite: false), .success)
        XCTAssertEqual(service.removeTrackIds, [currentTrack.trackId])
        XCTAssertFalse(viewModel.isCurrentTrackFavorite)
    }

    /// Системная команда не вызывает сервис и возвращает отказ без текущего трека.
    func testFavoriteRemoteCommandFailsWithoutCurrentTrack() {
        let service = PlayerFavoritesServiceSpy()
        let playerManager = PlayerFavoritesPlayerManagerSpy()
        _ = makeViewModel(
            favoritesService: service,
            playerManager: playerManager
        )

        XCTAssertEqual(playerManager.triggerFavoriteCommand(isFavorite: true), .commandFailed)
        XCTAssertEqual(service.addInputs, [])
        XCTAssertEqual(service.removeTrackIds, [])
    }

    /// Ошибка сохранения не меняет подтверждённое состояние команды и возвращает отказ системе.
    func testFavoriteRemoteCommandErrorPreservesConfirmedState() {
        let track = makeLocalTrack()
        let service = PlayerFavoritesServiceSpy()
        service.addError = PlayerFavoritesTestError.toggleFailed
        let playerManager = PlayerFavoritesPlayerManagerSpy()
        let viewModel = makeViewModel(
            favoritesService: service,
            playerManager: playerManager
        )

        viewModel.play(track: track)
        let statesBeforeCommand = playerManager.favoriteCommandStates

        XCTAssertEqual(playerManager.triggerFavoriteCommand(isFavorite: true), .commandFailed)
        XCTAssertFalse(viewModel.isCurrentTrackFavorite)
        XCTAssertEqual(playerManager.favoriteCommandStates, statesBeforeCommand)
    }

    /// iTunes-трек передаёт в системную команду тот же устойчивый идентификатор, что и «Избранное».
    func testFavoriteRemoteCommandUsesStablePurchasedITunesTrackId() {
        let track = makePurchasedITunesTrack()
        let service = PlayerFavoritesServiceSpy()
        let playerManager = PlayerFavoritesPlayerManagerSpy()
        let viewModel = makeViewModel(
            favoritesService: service,
            playerManager: playerManager
        )

        viewModel.play(track: track)

        XCTAssertEqual(playerManager.triggerFavoriteCommand(isFavorite: true), .success)
        XCTAssertEqual(service.addInputs.map(\.trackId), [track.trackId])
        XCTAssertEqual(service.addInputs.first?.source, .purchasedITunes)
    }

    /// Восстановленный локальный трек получает состояние после фактического появления display-модели.
    func testRestoredCurrentTrackReadsFavoritesState() async {
        let track = makeLibraryTrack()
        let service = PlayerFavoritesServiceSpy(favoriteTrackIds: [track.trackId])
        let statePersistence = PlayerFavoritesStatePersistenceSpy(
            state: makeRestoredLibraryState(trackId: track.trackId)
        )
        let viewModel = makeViewModel(
            favoritesService: service,
            statePersistence: statePersistence,
            fastLibraryTrackProvider: PlayerFavoritesFastLibraryTrackProvider(track: track),
            isLibraryAccessRestored: { false }
        )

        await waitUntil {
            viewModel.currentTrackDisplayable?.trackId == track.trackId
        }

        XCTAssertTrue(viewModel.isCurrentTrackFavorite)
        XCTAssertEqual(service.requestedFavoriteTrackIds, [track.trackId])
    }

    /// Единственная подписка не удерживает PlayerViewModel после завершения её жизненного цикла.
    func testFavoritesEventsSubscriptionDoesNotRetainPlayerViewModel() {
        let events = PlayerFavoritesEventsSubject()
        let playerManager = PlayerFavoritesPlayerManagerSpy()
        weak var weakViewModel: PlayerViewModel?

        do {
            let viewModel = makeViewModel(
                favoritesService: PlayerFavoritesServiceSpy(),
                favoritesEvents: events,
                playerManager: playerManager
            )
            weakViewModel = viewModel
        }

        XCTAssertNil(weakViewModel)
        XCTAssertEqual(playerManager.favoriteCommandRemovalCount, 1)
    }

    /// Создаёт ViewModel с изолированными зависимостями и без обращения к SQLite или AVPlayer.
    private func makeViewModel(
        favoritesService: PlayerFavoritesServiceSpy,
        favoritesEvents: PlayerFavoritesEventsSubject = PlayerFavoritesEventsSubject(),
        statePersistence: PlayerFavoritesStatePersistenceSpy = PlayerFavoritesStatePersistenceSpy(),
        playlistManager: PlaylistManager? = nil,
        fastLibraryTrackProvider: any FastLibraryTrackProviding = PlayerFavoritesFastLibraryTrackProvider(track: nil),
        isLibraryAccessRestored: @escaping @MainActor () -> Bool = { true },
        playerManager: PlayerFavoritesPlayerManagerSpy? = nil
    ) -> PlayerViewModel {
        let resolvedPlaylistManager = playlistManager ?? PlaylistManager(
            databaseStore: PlayerFavoritesQueuePersistenceSpy(),
            loadsInitialQueue: false
        )
        let resolvedPlayerManager = playerManager ?? PlayerFavoritesPlayerManagerSpy()

        return PlayerViewModel(
            playerManager: resolvedPlayerManager,
            playbackContextStore: PlayerPlaybackContextStore(
                playbackModePersistence: PlayerFavoritesPlaybackModePersistenceSpy()
            ),
            eventObserver: PlayerFavoritesEventObserverSpy(),
            toastPresenter: PlayerFavoritesToastPresenterSpy(),
            statePersistence: statePersistence,
            playlistManager: resolvedPlaylistManager,
            fastLibraryTrackProvider: fastLibraryTrackProvider,
            isLibraryAccessRestored: isLibraryAccessRestored,
            favoritesService: favoritesService,
            favoriteActionHandler: FavoriteTrackActionHandler(
                favoritesService: favoritesService
            ),
            favoritesEvents: favoritesEvents
        )
    }

    /// Связывает доступные из теста зависимости с очередью, нужной для сценария очистки.
    private func makeHarness(
        favoritesService: PlayerFavoritesServiceSpy
    ) -> PlayerFavoritesHarness {
        let playlistManager = PlaylistManager(
            databaseStore: PlayerFavoritesQueuePersistenceSpy(),
            loadsInitialQueue: false
        )

        return PlayerFavoritesHarness(
            viewModel: makeViewModel(
                favoritesService: favoritesService,
                playlistManager: playlistManager
            ),
            playlistManager: playlistManager
        )
    }

    /// Создаёт локальную строку очереди с каноническим UUID фонотеки.
    private func makeLocalTrack() -> PlayerTrack {
        PlayerTrack(
            trackId: UUID(),
            title: "Local title",
            artist: "Local artist",
            duration: 180,
            fileName: "Local.m4a",
            isAvailable: true
        )
    }

    /// Создаёт iTunes-строку очереди с устойчивым внешним UUID и готовым assetURL.
    private func makePurchasedITunesTrack() -> PlayerTrack {
        PlayerTrack(
            trackId: UUID.v5(from: "purchased-itunes:9001"),
            title: "Purchased title",
            artist: "Purchased artist",
            album: "Purchased album",
            artworkData: Data("artwork".utf8),
            duration: 200,
            fileName: "Purchased title",
            isAvailable: true,
            source: .purchasedITunes,
            assetURL: URL(string: "ipod-library://item/item.m4a?id=9001")
        )
    }

    /// Создаёт локальную display-модель для двухэтапного восстановления текущего трека.
    private func makeLibraryTrack() -> LibraryTrack {
        LibraryTrack(
            id: UUID(),
            fileURL: URL(fileURLWithPath: "/tmp/Restored.m4a"),
            title: "Restored title",
            artist: "Restored artist",
            duration: 180,
            addedDate: Date(),
            isAvailable: true
        )
    }

    /// Формирует сохранённый корневой контекст, достаточный для восстановления display-модели.
    private func makeRestoredLibraryState(trackId: UUID) -> PlayerStateDatabaseModel {
        PlayerStateDatabaseModel(
            id: 1,
            currentQueueItemId: nil,
            currentTrackId: trackId,
            contextType: .libraryRoot,
            contextId: nil,
            collectionCategory: nil,
            collectionValue: nil,
            collectionArtistKey: nil,
            playbackTime: 0,
            duration: 180,
            isPlaying: false,
            repeatMode: .off,
            shuffleEnabled: false,
            updatedAt: Date()
        )
    }

    /// Ожидает короткую асинхронную цепочку восстановления без привязки к задержке устройства.
    private func waitUntil(
        _ condition: @escaping () -> Bool
    ) async {
        for _ in 0..<100 {
            if condition() {
                return
            }
            await Task.yield()
        }

        XCTFail("Не выполнено ожидаемое условие восстановления")
    }
}

/// Фиксирует переданные сервису операции и позволяет тестам независимо задавать начальное состояние.
@MainActor
final class PlayerFavoritesServiceSpy: FavoritesServicing {

    var favoriteTrackIds: Set<UUID>
    var toggleError: Error?
    var addError: Error?
    var removeError: Error?
    private(set) var requestedFavoriteTrackIds: [UUID] = []
    private(set) var toggleInputs: [FavoriteTrackInput] = []
    private(set) var addInputs: [FavoriteTrackInput] = []
    private(set) var removeTrackIds: [UUID] = []

    init(favoriteTrackIds: Set<UUID> = []) {
        self.favoriteTrackIds = favoriteTrackIds
    }

    func loadFavoriteTrackIds() throws -> Set<UUID> {
        favoriteTrackIds
    }

    func isFavorite(trackId: UUID) throws -> Bool {
        requestedFavoriteTrackIds.append(trackId)
        return favoriteTrackIds.contains(trackId)
    }

    func add(_ track: FavoriteTrackInput) throws -> FavoritesMutationResult {
        addInputs.append(track)

        if let addError {
            throw addError
        }

        guard favoriteTrackIds.insert(track.trackId).inserted else {
            return .unchanged(isFavorite: true)
        }

        return .added
    }

    func remove(trackId: UUID) throws -> FavoritesMutationResult {
        removeTrackIds.append(trackId)

        if let removeError {
            throw removeError
        }

        guard favoriteTrackIds.remove(trackId) != nil else {
            return .unchanged(isFavorite: false)
        }

        return .removed
    }

    func toggle(_ track: FavoriteTrackInput) throws -> FavoritesMutationResult {
        toggleInputs.append(track)

        if let toggleError {
            throw toggleError
        }

        if favoriteTrackIds.remove(track.trackId) != nil {
            return .removed
        }

        favoriteTrackIds.insert(track.trackId)
        return .added
    }
}

/// Передаёт тестовые FavoritesChangeEvent тем же Combine-контрактом, что и production-центр событий.
final class PlayerFavoritesEventsSubject: FavoritesEventsObserving {

    private let subject = PassthroughSubject<FavoritesChangeEvent, Never>()

    var events: AnyPublisher<FavoritesChangeEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    func send(_ event: FavoritesChangeEvent) {
        subject.send(event)
    }
}

/// Исключает AVPlayer и глобальный Remote Command Center из unit-тестов, сохраняя контракт PlayerViewModel.
@MainActor
private final class PlayerFavoritesPlayerManagerSpy: PlayerManaging {

    /// Снимок состояния системной команды, который нужен для проверок ViewModel.
    struct FavoriteCommandState: Equatable {
        let isEnabled: Bool
        let isActive: Bool
    }

    private(set) var favoriteCommandSetupCount = 0
    private(set) var favoriteCommandRemovalCount = 0
    private(set) var favoriteCommandStates: [FavoriteCommandState] = []
    private var favoriteCommandHandler: (@MainActor (Bool) -> MPRemoteCommandHandlerStatus)?

    func play(
        track: any TrackDisplayable,
        onPreparedLocalFile: @escaping PlayerPreparedLocalFileHandler
    ) async throws {}

    func playCurrent() {}

    func restartCurrent() {}

    func pause() {}

    func seek(to time: TimeInterval) {}

    func stopAccessingCurrentTrack() {}

    func preparedLocalFileURL(for trackId: UUID) -> URL? {
        nil
    }

    func observeProgress(update: @escaping (TimeInterval) -> Void) {}

    func removeTimeObserver() {}

    func setupRemoteCommandCenter(
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onPrevious: @escaping () -> Void
    ) {}

    func configureFavoriteCommand(
        handler: @escaping @MainActor (Bool) -> MPRemoteCommandHandlerStatus
    ) {
        favoriteCommandSetupCount += 1
        favoriteCommandHandler = handler
    }

    func updateFavoriteCommand(
        isEnabled: Bool,
        isActive: Bool
    ) {
        favoriteCommandStates.append(
            FavoriteCommandState(
                isEnabled: isEnabled,
                isActive: isActive
            )
        )
    }

    func removeFavoriteCommandHandler() {
        favoriteCommandRemovalCount += 1
        favoriteCommandHandler = nil
    }

    /// Имитирует системное событие с уже вычисленным итоговым состоянием обратной связи.
    func triggerFavoriteCommand(isFavorite: Bool) -> MPRemoteCommandHandlerStatus {
        favoriteCommandHandler?(isFavorite) ?? .commandFailed
    }

    func applyNowPlaying(snapshot: NowPlayingSnapshot) {}

    func applyPlaybackTime(currentTime: TimeInterval, isPlaying: Bool) {}
}

/// Предоставляет PlayerViewModel только необходимые тестовые callbacks playback-событий.
@MainActor
private final class PlayerFavoritesEventObserverSpy: PlayerEventObserving {

    var onTrackDurationUpdated: ((TimeInterval) -> Void)?
    var onTrackDidFinish: (() -> Void)?
    var onTrackDidUpdate: ((TrackUpdateEvent) -> Void)?
    var onSettingsChanged: (() -> Void)?
}

/// Не показывает UI при преднамеренно тестируемых ошибках доменного сервиса.
@MainActor
private final class PlayerFavoritesToastPresenterSpy: ToastPresenting {

    func handle(_ event: ToastEvent, duration: TimeInterval) {}

    func handle(_ error: AppError) {}
}

/// Хранит только данные, которыми PlayerViewModel подтверждает очистку текущей очереди.
private final class PlayerFavoritesStatePersistenceSpy: PlayerStatePersisting {

    var state: PlayerStateDatabaseModel?

    init(state: PlayerStateDatabaseModel? = nil) {
        self.state = state
    }

    func loadState() throws -> PlayerStateDatabaseModel? {
        state
    }

    func saveCurrentTrack(
        trackId: UUID,
        queueItemId: UUID?,
        duration: TimeInterval,
        playbackMode: PlaybackMode,
        contextSource: PlaybackContextSource
    ) throws {
        state = PlayerStateDatabaseModel(
            id: 1,
            currentQueueItemId: queueItemId,
            currentTrackId: trackId,
            contextType: .playerQueue,
            contextId: nil,
            collectionCategory: nil,
            collectionValue: nil,
            collectionArtistKey: nil,
            playbackTime: 0,
            duration: duration,
            isPlaying: false,
            repeatMode: DatabaseRepeatMode(rawValue: playbackMode.repeatMode.rawValue) ?? .off,
            shuffleEnabled: playbackMode.isShuffleEnabled,
            updatedAt: Date()
        )
    }

    func clearState() throws {
        state = nil
    }
}

/// Отключает чтение AppSettings при создании playback-контекста в изолированных тестах.
@MainActor
private final class PlayerFavoritesPlaybackModePersistenceSpy: PlaybackModePersisting {

    func loadPlaybackMode() -> PlaybackMode {
        PlaybackMode(isShuffleEnabled: false, repeatMode: .off)
    }

    func savePlaybackMode(_ mode: PlaybackMode) {}
}

/// Исключает SQLite-очередь из подготовки PlayerViewModel в тестах.
private final class PlayerFavoritesQueuePersistenceSpy: PlayerQueuePersisting {

    func fetchQueue() throws -> [PlayerTrack] {
        []
    }

    func replaceQueue(_ tracks: [PlayerTrack]) throws {}
}

/// Возвращает заранее заданную раннюю display-модель для сценария восстановления.
private final class PlayerFavoritesFastLibraryTrackProvider: FastLibraryTrackProviding {

    private let track: LibraryTrack?

    init(track: LibraryTrack?) {
        self.track = track
    }

    func track(for trackId: UUID) async -> LibraryTrack? {
        guard track?.trackId == trackId else {
            return nil
        }

        return track
    }
}

/// Связывает ViewModel и её тестовую очередь для проверки очистки текущего трека.
private struct PlayerFavoritesHarness {

    let viewModel: PlayerViewModel
    let playlistManager: PlaylistManager
}

/// Локальная ошибка отличает неуспешный toggle от состояний доменного сервиса.
private enum PlayerFavoritesTestError: Error {
    case toggleFailed
}
