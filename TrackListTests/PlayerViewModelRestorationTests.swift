//
//  PlayerViewModelRestorationTests.swift
//  TrackList
//
//  Проверки двухэтапного восстановления последнего трека в мини-плеере.
//
//  Created by Pavel Fomin on 28.07.2026.
//

import Foundation
import XCTest
@testable import TrackList

@MainActor
final class PlayerViewModelRestorationTests: XCTestCase {

    /// При отсутствии записи player_state мини-плеер сразу подтверждает пустое состояние.
    func testMissingSavedStatePublishesEmptyMiniPlayer() {
        let statePersistence = RestorationStatePersistenceSpy(state: nil)
        let viewModel = makeViewModel(
            statePersistence: statePersistence,
            fastTrackProvider: FastLibraryTrackProviderSpy(track: nil),
            libraryAccessState: LibraryAccessState(isRestored: false)
        )

        XCTAssertEqual(viewModel.miniPlayerState, .empty)
        XCTAssertNil(viewModel.currentTrackDisplayable)
        XCTAssertEqual(statePersistence.clearCallsCount, 0)
    }

    /// Трек из реестра появляется до завершения bookmark-доступа и не запускает подготовку воспроизведения.
    func testLibraryTrackAppearsBeforeLibraryAccessRestored() async {
        let track = makeLibraryTrack(
            fileName: "Early Library Track.m4a",
            title: "Saved Title",
            artist: "Saved Artist"
        )
        let playerManager = RestorationPlayerManagerSpy()
        let viewModel = makeViewModel(
            playerManager: playerManager,
            statePersistence: RestorationStatePersistenceSpy(
                state: makeLibraryState(trackId: track.trackId)
            ),
            fastTrackProvider: FastLibraryTrackProviderSpy(track: track),
            libraryAccessState: LibraryAccessState(isRestored: false)
        )

        await waitUntil {
            viewModel.currentTrackDisplayable?.trackId == track.trackId
        }

        XCTAssertEqual(viewModel.currentTrackDisplayable?.trackId, track.trackId)
        XCTAssertEqual(miniPlayerTrackId(in: viewModel.miniPlayerState), track.trackId)
        XCTAssertEqual(miniPlayerStaticState(in: viewModel.miniPlayerState)?.title, "Saved Title")
        XCTAssertEqual(miniPlayerStaticState(in: viewModel.miniPlayerState)?.artist, "Saved Artist")
        XCTAssertNil(viewModel.snapshot(for: track.trackId))
        XCTAssertFalse(viewModel.isPlaybackContextReady)
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertEqual(playerManager.playCallsCount, 0)
    }

    /// Отсутствующее сохранённое название использует имя файла только как предусмотренный fallback.
    func testEarlyLibraryTrackUsesFileNameWhenCachedTitleIsMissing() async {
        let track = makeLibraryTrack(
            fileName: "Fallback Title.m4a",
            title: nil,
            artist: "Saved Artist"
        )
        let viewModel = makeViewModel(
            statePersistence: RestorationStatePersistenceSpy(
                state: makeLibraryState(trackId: track.trackId)
            ),
            fastTrackProvider: FastLibraryTrackProviderSpy(track: track),
            libraryAccessState: LibraryAccessState(isRestored: false)
        )

        await waitUntil {
            self.miniPlayerStaticState(in: viewModel.miniPlayerState)?.trackId == track.trackId
        }

        XCTAssertEqual(
            miniPlayerStaticState(in: viewModel.miniPlayerState)?.title,
            "Fallback Title.m4a"
        )
        XCTAssertEqual(miniPlayerStaticState(in: viewModel.miniPlayerState)?.artist, "Saved Artist")
    }

    /// Отсутствующий артист не заменяется именем файла и передаётся в существующий presentation fallback.
    func testEarlyLibraryTrackKeepsArtistMissingWhenCachedArtistIsMissing() async {
        let track = makeLibraryTrack(
            fileName: "No Artist.m4a",
            title: "Saved Title",
            artist: nil
        )
        let viewModel = makeViewModel(
            statePersistence: RestorationStatePersistenceSpy(
                state: makeLibraryState(trackId: track.trackId)
            ),
            fastTrackProvider: FastLibraryTrackProviderSpy(track: track),
            libraryAccessState: LibraryAccessState(isRestored: false)
        )

        await waitUntil {
            self.miniPlayerStaticState(in: viewModel.miniPlayerState)?.trackId == track.trackId
        }

        XCTAssertEqual(miniPlayerStaticState(in: viewModel.miniPlayerState)?.title, "Saved Title")
        XCTAssertNil(miniPlayerStaticState(in: viewModel.miniPlayerState)?.artist)
    }

    /// До загрузки полного context оба перехода недоступны и прямые вызовы не создают ложное воспроизведение.
    func testEarlyLibraryTrackDisablesNavigationUntilContextIsRestored() async {
        let track = makeLibraryTrack(fileName: "Early Navigation.m4a")
        let playerManager = RestorationPlayerManagerSpy()
        let viewModel = makeViewModel(
            playerManager: playerManager,
            statePersistence: RestorationStatePersistenceSpy(
                state: makeLibraryState(trackId: track.trackId)
            ),
            fastTrackProvider: FastLibraryTrackProviderSpy(track: track),
            libraryAccessState: LibraryAccessState(isRestored: false)
        )

        await waitUntil {
            viewModel.currentTrackDisplayable?.trackId == track.trackId
        }

        viewModel.playPreviousTrack()
        viewModel.playNextTrack()
        await Task.yield()

        XCTAssertFalse(viewModel.isPlaybackContextReady)
        XCTAssertFalse(viewModel.canPlayPreviousTrack)
        XCTAssertFalse(viewModel.canPlayNextTrack)
        XCTAssertEqual(playerManager.playCallsCount, 0)
    }

    /// До готовности фонотеки отсутствие записи не очищает player_state; после повторной проверки очищается ровно один раз.
    func testMissingLibraryTrackIsClearedOnlyAfterLibraryAccessRestored() async {
        let trackId = UUID()
        let statePersistence = RestorationStatePersistenceSpy(
            state: makeLibraryState(trackId: trackId)
        )
        let accessState = LibraryAccessState(isRestored: false)
        let fastTrackProvider = FastLibraryTrackProviderSpy(track: nil)
        let viewModel = makeViewModel(
            statePersistence: statePersistence,
            fastTrackProvider: fastTrackProvider,
            libraryAccessState: accessState
        )

        await waitUntil {
            fastTrackProvider.requestsCount == 1
        }

        XCTAssertEqual(viewModel.miniPlayerState, .loading(staticState: nil))
        XCTAssertEqual(statePersistence.clearCallsCount, 0)

        accessState.isRestored = true
        NotificationCenter.default.post(name: .libraryAccessRestored, object: nil)

        await waitUntil {
            statePersistence.clearCallsCount == 1
        }

        XCTAssertEqual(viewModel.miniPlayerState, .empty)
        XCTAssertNil(viewModel.currentTrackDisplayable)
        XCTAssertGreaterThanOrEqual(fastTrackProvider.requestsCount, 2)
    }

    /// Поздний context восстанавливает переход Next, не заменяя уже показанный трек и не создавая второй запуск Play.
    func testLateLibraryContextEnablesNextWithoutReplacingDisplayedTrack() async {
        let firstTrack = makeLibraryTrack(fileName: "First.m4a")
        let secondTrack = makeLibraryTrack(fileName: "Second.m4a")
        let playerManager = RestorationPlayerManagerSpy()
        let accessState = LibraryAccessState(isRestored: false)
        let contextLoader = LibraryContextLoaderSpy(tracks: [firstTrack, secondTrack])
        let viewModel = makeViewModel(
            playerManager: playerManager,
            statePersistence: RestorationStatePersistenceSpy(
                state: makeLibraryState(trackId: firstTrack.trackId)
            ),
            libraryContextLoader: contextLoader,
            fastTrackProvider: FastLibraryTrackProviderSpy(track: firstTrack),
            libraryAccessState: accessState
        )

        await waitUntil {
            viewModel.currentTrackDisplayable?.trackId == firstTrack.trackId
        }

        accessState.isRestored = true
        NotificationCenter.default.post(name: .libraryAccessRestored, object: nil)

        await waitUntil {
            viewModel.isPlaybackContextReady
        }

        XCTAssertEqual(viewModel.currentTrackDisplayable?.trackId, firstTrack.trackId)
        XCTAssertFalse(viewModel.canPlayPreviousTrack)
        XCTAssertTrue(viewModel.canPlayNextTrack)

        viewModel.playNextTrack()

        await waitUntil {
            playerManager.playedTrackIds.contains(secondTrack.trackId)
        }

        XCTAssertEqual(viewModel.currentTrackDisplayable?.trackId, secondTrack.trackId)
        XCTAssertEqual(playerManager.playedTrackIds, [secondTrack.trackId])
    }

    /// Последний трек линейного context разрешает только переход назад после позднего восстановления.
    func testLastTrackEnablesOnlyPreviousAfterContextIsRestored() async {
        let firstTrack = makeLibraryTrack(fileName: "First.m4a")
        let lastTrack = makeLibraryTrack(fileName: "Last.m4a")
        let accessState = LibraryAccessState(isRestored: false)
        let viewModel = makeViewModel(
            statePersistence: RestorationStatePersistenceSpy(
                state: makeLibraryState(trackId: lastTrack.trackId)
            ),
            libraryContextLoader: LibraryContextLoaderSpy(tracks: [firstTrack, lastTrack]),
            fastTrackProvider: FastLibraryTrackProviderSpy(track: lastTrack),
            libraryAccessState: accessState
        )

        await waitUntil {
            viewModel.currentTrackDisplayable?.trackId == lastTrack.trackId
        }

        accessState.isRestored = true
        NotificationCenter.default.post(name: .libraryAccessRestored, object: nil)

        await waitUntil {
            viewModel.isPlaybackContextReady
        }

        XCTAssertTrue(viewModel.canPlayPreviousTrack)
        XCTAssertFalse(viewModel.canPlayNextTrack)
    }

    /// Контекст из одного трека не создаёт искусственных переходов при выключенном repeat all.
    func testSingleTrackContextKeepsBothNavigationActionsDisabled() async {
        let track = makeLibraryTrack(fileName: "Only.m4a")
        let accessState = LibraryAccessState(isRestored: false)
        let viewModel = makeViewModel(
            statePersistence: RestorationStatePersistenceSpy(
                state: makeLibraryState(trackId: track.trackId)
            ),
            libraryContextLoader: LibraryContextLoaderSpy(tracks: [track]),
            fastTrackProvider: FastLibraryTrackProviderSpy(track: track),
            libraryAccessState: accessState
        )

        await waitUntil {
            viewModel.currentTrackDisplayable?.trackId == track.trackId
        }

        accessState.isRestored = true
        NotificationCenter.default.post(name: .libraryAccessRestored, object: nil)

        await waitUntil {
            viewModel.isPlaybackContextReady
        }

        XCTAssertFalse(viewModel.canPlayPreviousTrack)
        XCTAssertFalse(viewModel.canPlayNextTrack)
    }

    /// Поздний context не возвращает прежний трек, если пользователь уже выбрал другой готовый context.
    func testLateContextDoesNotReplaceUserSelectedTrack() async {
        let restoredTrack = makeLibraryTrack(fileName: "Restored.m4a")
        let selectedTrack = makeLibraryTrack(fileName: "Selected.m4a")
        let accessState = LibraryAccessState(isRestored: false)
        let contextLoader = DelayedLibraryContextLoaderSpy(tracks: [restoredTrack])
        let viewModel = makeViewModel(
            statePersistence: RestorationStatePersistenceSpy(
                state: makeLibraryState(trackId: restoredTrack.trackId)
            ),
            libraryContextLoader: contextLoader,
            fastTrackProvider: FastLibraryTrackProviderSpy(track: restoredTrack),
            libraryAccessState: accessState
        )

        await waitUntil {
            viewModel.currentTrackDisplayable?.trackId == restoredTrack.trackId
        }

        accessState.isRestored = true
        NotificationCenter.default.post(name: .libraryAccessRestored, object: nil)

        await waitUntil {
            contextLoader.loadRootCallsCount == 1
        }

        viewModel.play(
            track: selectedTrack,
            context: [selectedTrack],
            source: .libraryRoot
        )
        await waitUntil {
            viewModel.currentTrackDisplayable?.trackId == selectedTrack.trackId
        }

        contextLoader.completeLoad()
        await Task.yield()

        XCTAssertEqual(viewModel.currentTrackDisplayable?.trackId, selectedTrack.trackId)
        XCTAssertTrue(viewModel.isPlaybackContextReady)
        XCTAssertFalse(viewModel.canPlayPreviousTrack)
        XCTAssertFalse(viewModel.canPlayNextTrack)
    }

    /// Поздний runtime snapshot может добавить artwork, не заменяя сохранённые ранние теги fallback-значениями.
    func testLateRuntimeSnapshotKeepsEarlyCachedMetadataAndAddsArtworkRequest() async {
        let track = makeLibraryTrack(
            fileName: "Snapshot Fallback.m4a",
            title: "Saved Title",
            artist: "Saved Artist"
        )
        let eventObserver = RestorationPlayerEventObserverSpy()
        let viewModel = makeViewModel(
            eventObserver: eventObserver,
            statePersistence: RestorationStatePersistenceSpy(
                state: makeLibraryState(trackId: track.trackId)
            ),
            fastTrackProvider: FastLibraryTrackProviderSpy(track: track),
            libraryAccessState: LibraryAccessState(isRestored: false)
        )

        await waitUntil {
            self.miniPlayerStaticState(in: viewModel.miniPlayerState)?.trackId == track.trackId
        }

        let snapshot = makeRuntimeSnapshotWithArtwork(trackId: track.trackId)
        eventObserver.onTrackDidUpdate?(
            TrackUpdateEvent(
                trackId: track.trackId,
                reason: .artworkUpdated,
                changedFields: [.artworkData],
                snapshot: snapshot
            )
        )

        let expectedArtworkRequest = ArtworkRequest(
            trackId: track.trackId,
            snapshot: snapshot,
            purpose: .miniPlayer
        )
        XCTAssertEqual(miniPlayerStaticState(in: viewModel.miniPlayerState)?.title, "Saved Title")
        XCTAssertEqual(miniPlayerStaticState(in: viewModel.miniPlayerState)?.artist, "Saved Artist")
        XCTAssertEqual(
            miniPlayerStaticState(in: viewModel.miniPlayerState)?.artworkRequest?.loadIdentifier,
            expectedArtworkRequest?.loadIdentifier
        )
    }

    /// Повторное Play до завершения подготовки не создаёт второй параллельный запрос в PlayerManager.
    func testRepeatedPlayDuringEarlyRestorationStartsPreparationOnce() async {
        let track = makeLibraryTrack(fileName: "Prepared Once.m4a")
        let playerManager = RestorationPlayerManagerSpy()
        playerManager.delaysPlayCompletion = true
        let viewModel = makeViewModel(
            playerManager: playerManager,
            statePersistence: RestorationStatePersistenceSpy(
                state: makeLibraryState(trackId: track.trackId)
            ),
            fastTrackProvider: FastLibraryTrackProviderSpy(track: track),
            libraryAccessState: LibraryAccessState(isRestored: false)
        )

        await waitUntil {
            viewModel.currentTrackDisplayable?.trackId == track.trackId
        }

        viewModel.togglePlayPause()
        viewModel.togglePlayPause()

        await waitUntil {
            playerManager.playCallsCount == 1
        }

        XCTAssertEqual(playerManager.playCallsCount, 1)
        XCTAssertFalse(viewModel.isPlaying)

        playerManager.completePlay()

        await waitUntil {
            viewModel.isPlaying
        }
    }

    /// Собирает ViewModel только с изолированными зависимостями, чтобы тесты не обращались к SQLite, bookmark и AVPlayer.
    private func makeViewModel(
        playerManager: RestorationPlayerManagerSpy = RestorationPlayerManagerSpy(),
        eventObserver: RestorationPlayerEventObserverSpy? = nil,
        statePersistence: RestorationStatePersistenceSpy,
        libraryContextLoader: (any LibraryPlaybackContextLoading)? = nil,
        fastTrackProvider: any FastLibraryTrackProviding,
        libraryAccessState: LibraryAccessState
    ) -> PlayerViewModel {
        PlayerViewModel(
            playerManager: playerManager,
            playbackContextStore: PlayerPlaybackContextStore(
                playbackModePersistence: RestorationPlaybackModePersistenceSpy()
            ),
            eventObserver: eventObserver ?? RestorationPlayerEventObserverSpy(),
            toastPresenter: RestorationToastPresenterSpy(),
            statePersistence: statePersistence,
            playlistManager: PlaylistManager(
                databaseStore: RestorationPlayerQueuePersistenceSpy(),
                loadsInitialQueue: false
            ),
            libraryContextLoader: libraryContextLoader,
            fastLibraryTrackProvider: fastTrackProvider,
            isLibraryAccessRestored: { libraryAccessState.isRestored }
        )
    }

    /// Формирует сохранённое состояние корневого контекста без метаданных трека.
    private func makeLibraryState(trackId: UUID) -> PlayerStateDatabaseModel {
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

    /// Создаёт display-модель без физического файла: PlayerManager в этих проверках её не использует.
    private func makeLibraryTrack(
        fileName: String,
        title: String? = nil,
        artist: String? = nil
    ) -> LibraryTrack {
        LibraryTrack(
            id: UUID(),
            fileURL: URL(fileURLWithPath: "/tmp/\(fileName)"),
            title: title,
            artist: artist,
            duration: 180,
            addedDate: Date(),
            isAvailable: false
        )
    }

    /// Создаёт поздний snapshot с artwork и пустыми тегами, чтобы проверить сохранение раннего metadata fallback.
    private func makeRuntimeSnapshotWithArtwork(trackId: UUID) -> TrackRuntimeSnapshot {
        let artworkData = Data("late artwork".utf8)
        return TrackRuntimeSnapshot(
            trackId: trackId,
            fileName: "Snapshot Fallback.m4a",
            isAvailable: true,
            technicalMetadata: TrackTechnicalMetadata(
                fileSizeBytes: nil,
                fileFormat: nil,
                bitrateBitsPerSecond: nil
            ),
            title: nil,
            artist: nil,
            album: nil,
            albumArtist: nil,
            genre: nil,
            comment: nil,
            composer: nil,
            conductor: nil,
            lyricist: nil,
            remixer: nil,
            grouping: nil,
            bpm: nil,
            musicalKey: nil,
            trackNumber: nil,
            totalTracks: nil,
            discNumber: nil,
            totalDiscs: nil,
            year: nil,
            date: nil,
            publisherOrLabel: nil,
            copyright: nil,
            encodedBy: nil,
            isrc: nil,
            duration: 180,
            artworkData: artworkData,
            artworkSourceIdentifier: .embeddedArtwork(data: artworkData),
            updatedAt: Date()
        )
    }

    /// Извлекает идентификатор только из playback-состояний мини-плеера.
    private func miniPlayerTrackId(in state: MiniPlayerState) -> UUID? {
        switch state {
        case let .playing(staticState, _),
             let .paused(staticState, _):
            return staticState.trackId
        case .empty,
             .loading,
             .error:
            return nil
        }
    }

    /// Извлекает статические данные из playback-состояний, не привязывая тест к текущему прогрессу.
    private func miniPlayerStaticState(in state: MiniPlayerState) -> MiniPlayerStaticState? {
        switch state {
        case let .playing(staticState, _),
             let .paused(staticState, _):
            return staticState
        case .empty,
             .loading,
             .error:
            return nil
        }
    }

    /// Ожидает короткую асинхронную цепочку без привязки к длительности устройства или симулятора.
    private func waitUntil(
        _ condition: @escaping () -> Bool
    ) async {
        for _ in 0..<100 {
            if condition() {
                return
            }

            await Task.yield()
        }

        XCTFail("Не выполнено ожидаемое асинхронное условие")
    }
}

/// Хранит управляемую тестом готовность доступа к фонотеке.
@MainActor
private final class LibraryAccessState {
    var isRestored: Bool

    init(isRestored: Bool) {
        self.isRestored = isRestored
    }
}

/// Возвращает один реестровый трек и фиксирует число быстрых запросов без файловой системы.
private final class FastLibraryTrackProviderSpy: FastLibraryTrackProviding {
    private let track: LibraryTrack?
    private(set) var requestsCount = 0

    init(track: LibraryTrack?) {
        self.track = track
    }

    func track(for trackId: UUID) async -> LibraryTrack? {
        requestsCount += 1
        return track
    }
}

/// Эмулирует единственную строку player_state и фиксирует её очистку.
private final class RestorationStatePersistenceSpy: PlayerStatePersisting {
    private var state: PlayerStateDatabaseModel?
    private(set) var clearCallsCount = 0

    init(state: PlayerStateDatabaseModel?) {
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
    ) throws {}

    func clearState() throws {
        clearCallsCount += 1
        state = nil
    }
}

/// Возвращает тестовый корневой playback-контекст без обращения к TrackRegistry.
@MainActor
private final class LibraryContextLoaderSpy: LibraryPlaybackContextLoading {
    private let tracks: [LibraryTrack]
    private(set) var loadRootCallsCount = 0

    init(tracks: [LibraryTrack]) {
        self.tracks = tracks
    }

    func loadFolderContext(folderId: UUID) async throws -> [LibraryTrack] {
        []
    }

    func loadRootContext() async throws -> [LibraryTrack] {
        loadRootCallsCount += 1
        return tracks
    }

    func loadCollectionContext(
        category: LibraryCollectionCategory,
        rawValue: String,
        artistKey: String?
    ) async throws -> [LibraryTrack] {
        []
    }
}

/// Удерживает позднюю загрузку context до явного завершения, чтобы проверить приоритет пользовательского выбора.
@MainActor
private final class DelayedLibraryContextLoaderSpy: LibraryPlaybackContextLoading {
    private let tracks: [LibraryTrack]
    private var loadContinuation: CheckedContinuation<[LibraryTrack], Never>?
    private(set) var loadRootCallsCount = 0

    init(tracks: [LibraryTrack]) {
        self.tracks = tracks
    }

    func loadFolderContext(folderId: UUID) async throws -> [LibraryTrack] {
        []
    }

    func loadRootContext() async throws -> [LibraryTrack] {
        loadRootCallsCount += 1
        return await withCheckedContinuation { continuation in
            loadContinuation = continuation
        }
    }

    func loadCollectionContext(
        category: LibraryCollectionCategory,
        rawValue: String,
        artistKey: String?
    ) async throws -> [LibraryTrack] {
        []
    }

    /// Отдаёт исходный context после того, как тест сменил текущий трек.
    func completeLoad() {
        loadContinuation?.resume(returning: tracks)
        loadContinuation = nil
    }
}

/// Подменяет AVPlayer и запоминает только факты запуска, нужные для восстановления контекста.
private final class RestorationPlayerManagerSpy: PlayerManaging {
    private(set) var playedTrackIds: [UUID] = []
    private var playCompletionContinuation: CheckedContinuation<Void, Never>?
    var delaysPlayCompletion = false

    var playCallsCount: Int {
        playedTrackIds.count
    }

    func play(
        track: any TrackDisplayable,
        onPreparedLocalFile: @escaping PlayerPreparedLocalFileHandler
    ) async throws {
        playedTrackIds.append(track.trackId)

        guard delaysPlayCompletion else { return }
        await withCheckedContinuation { continuation in
            playCompletionContinuation = continuation
        }
    }

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

    func applyNowPlaying(snapshot: NowPlayingSnapshot) {}

    func applyPlaybackTime(currentTime: TimeInterval, isPlaying: Bool) {}

    /// Завершает искусственную подготовку, чтобы ViewModel опубликовала playing только после неё.
    func completePlay() {
        playCompletionContinuation?.resume()
        playCompletionContinuation = nil
    }
}

/// Не загружает очередь во время проверки изолированного стартового восстановления.
private final class RestorationPlayerQueuePersistenceSpy: PlayerQueuePersisting {
    func fetchQueue() throws -> [PlayerTrack] {
        []
    }

    func replaceQueue(_ tracks: [PlayerTrack]) throws {}
}

/// Изолирует PlayerPlaybackContextStore от постоянных настроек приложения.
@MainActor
private final class RestorationPlaybackModePersistenceSpy: PlaybackModePersisting {
    func loadPlaybackMode() -> PlaybackMode {
        PlaybackMode(isShuffleEnabled: false, repeatMode: .off)
    }

    func savePlaybackMode(_ mode: PlaybackMode) {}
}

/// Не подписывается на системные уведомления и предоставляет ViewModel пустые обработчики событий playback.
@MainActor
private final class RestorationPlayerEventObserverSpy: PlayerEventObserving {
    var onTrackDurationUpdated: ((TimeInterval) -> Void)?
    var onTrackDidFinish: (() -> Void)?
    var onTrackDidUpdate: ((TrackUpdateEvent) -> Void)?
    var onSettingsChanged: (() -> Void)?
}

/// Не показывает пользовательские сообщения в проверках без AVPlayer.
@MainActor
private final class RestorationToastPresenterSpy: ToastPresenting {
    func handle(_ event: ToastEvent, duration: TimeInterval) {}

    func handle(_ error: AppError) {}
}
