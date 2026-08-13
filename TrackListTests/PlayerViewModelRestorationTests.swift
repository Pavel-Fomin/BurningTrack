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

    /// Локальный контекст строится из SQLite до окончания синхронизации фонотеки.
    func testLibraryContextBecomesReadyBeforeLibraryAccessRestored() async {
        let firstTrack = makeLibraryTrack(fileName: "Early First.m4a")
        let secondTrack = makeLibraryTrack(fileName: "Early Second.m4a")
        let playerManager = RestorationPlayerManagerSpy()
        let contextLoader = LibraryContextLoaderSpy(tracks: [firstTrack, secondTrack])
        let viewModel = makeViewModel(
            playerManager: playerManager,
            statePersistence: RestorationStatePersistenceSpy(
                state: makeLibraryState(trackId: firstTrack.trackId)
            ),
            libraryContextLoader: contextLoader,
            fastTrackProvider: FastLibraryTrackProviderSpy(track: firstTrack),
            libraryAccessState: LibraryAccessState(isRestored: false)
        )

        await waitUntil {
            viewModel.isPlaybackContextReady
        }

        XCTAssertEqual(viewModel.currentTrackDisplayable?.trackId, firstTrack.trackId)
        XCTAssertEqual(contextLoader.loadRootCallsCount, 1)
        XCTAssertTrue(viewModel.isPlaybackContextReady)
        XCTAssertFalse(viewModel.canPlayPreviousTrack)
        XCTAssertTrue(viewModel.canPlayNextTrack)
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertEqual(playerManager.playCallsCount, 0)
    }

    /// Предварительный SQLite-контекст разрешает переход Next до полной синхронизации.
    func testPreliminaryLibraryContextAllowsNextBeforeLibraryAccessRestored() async {
        let firstTrack = makeLibraryTrack(fileName: "Preliminary First.m4a")
        let secondTrack = makeLibraryTrack(fileName: "Preliminary Second.m4a")
        let playerManager = RestorationPlayerManagerSpy()
        let viewModel = makeViewModel(
            playerManager: playerManager,
            statePersistence: RestorationStatePersistenceSpy(
                state: makeLibraryState(trackId: firstTrack.trackId)
            ),
            libraryContextLoader: LibraryContextLoaderSpy(tracks: [firstTrack, secondTrack]),
            fastTrackProvider: FastLibraryTrackProviderSpy(track: firstTrack),
            libraryAccessState: LibraryAccessState(isRestored: false)
        )

        await waitUntil {
            viewModel.isPlaybackContextReady && viewModel.canPlayNextTrack
        }

        viewModel.playNextTrack()

        await waitUntil {
            playerManager.playedTrackIds == [secondTrack.trackId]
        }

        XCTAssertEqual(viewModel.currentTrackDisplayable?.trackId, secondTrack.trackId)
        XCTAssertEqual(playerManager.playCallsCount, 1)
    }

    /// Предварительный контекст не запускает воспроизведение без явного действия пользователя.
    func testPreliminaryLibraryContextDoesNotStartPlayAutomatically() async {
        let firstTrack = makeLibraryTrack(fileName: "No Auto Play First.m4a")
        let secondTrack = makeLibraryTrack(fileName: "No Auto Play Second.m4a")
        let playerManager = RestorationPlayerManagerSpy()
        let viewModel = makeViewModel(
            playerManager: playerManager,
            statePersistence: RestorationStatePersistenceSpy(
                state: makeLibraryState(trackId: firstTrack.trackId)
            ),
            libraryContextLoader: LibraryContextLoaderSpy(tracks: [firstTrack, secondTrack]),
            fastTrackProvider: FastLibraryTrackProviderSpy(track: firstTrack),
            libraryAccessState: LibraryAccessState(isRestored: false)
        )

        await waitUntil {
            viewModel.isPlaybackContextReady
        }

        XCTAssertFalse(viewModel.isPlaying)
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

    /// Окончательная стадия заменяет предварительный порядок после синхронизации, не меняя текущий трек и не запуская воспроизведение.
    func testFinalLibraryContextUpdatesPreliminaryContextAfterLibraryAccessRestored() async {
        let firstTrack = makeLibraryTrack(fileName: "Final First.m4a")
        let preliminarySecondTrack = makeLibraryTrack(fileName: "Final Preliminary Second.m4a")
        let playerManager = RestorationPlayerManagerSpy()
        let accessState = LibraryAccessState(isRestored: false)
        let contextLoader = SequencedLibraryContextLoaderSpy(
            contexts: [[firstTrack, preliminarySecondTrack], [firstTrack]]
        )
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
            viewModel.isPlaybackContextReady && viewModel.canPlayNextTrack
        }

        accessState.isRestored = true
        NotificationCenter.default.post(name: .libraryAccessRestored, object: nil)

        await waitUntil {
            contextLoader.loadRootCallsCount == 2 && viewModel.canPlayNextTrack == false
        }

        XCTAssertEqual(viewModel.currentTrackDisplayable?.trackId, firstTrack.trackId)
        XCTAssertTrue(viewModel.isPlaybackContextReady)
        XCTAssertFalse(viewModel.canPlayPreviousTrack)
        XCTAssertFalse(viewModel.canPlayNextTrack)
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertEqual(playerManager.playCallsCount, 0)
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

    /// Поздний окончательный контекст не возвращает прежний трек, если пользователь уже выбрал другой готовый контекст.
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

        await waitUntil {
            viewModel.isPlaybackContextReady
        }

        accessState.isRestored = true
        NotificationCenter.default.post(name: .libraryAccessRestored, object: nil)

        await waitUntil {
            contextLoader.loadRootCallsCount == 2
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

    /// Повторные события до завершения предварительной загрузки не создают параллельные запросы контекста.
    func testRepeatedLibraryAccessEventsDoNotStartParallelContextLoads() async {
        let firstTrack = makeLibraryTrack(fileName: "Repeated First.m4a")
        let secondTrack = makeLibraryTrack(fileName: "Repeated Second.m4a")
        let accessState = LibraryAccessState(isRestored: false)
        let contextLoader = DelayedLibraryContextLoaderSpy(
            tracks: [firstTrack, secondTrack],
            delaysFirstLoad: true
        )
        let viewModel = makeViewModel(
            statePersistence: RestorationStatePersistenceSpy(
                state: makeLibraryState(trackId: firstTrack.trackId)
            ),
            libraryContextLoader: contextLoader,
            fastTrackProvider: FastLibraryTrackProviderSpy(track: firstTrack),
            libraryAccessState: accessState
        )

        await waitUntil {
            contextLoader.loadRootCallsCount == 1
        }

        NotificationCenter.default.post(name: .libraryAccessRestored, object: nil)
        NotificationCenter.default.post(name: .libraryAccessRestored, object: nil)
        await Task.yield()

        XCTAssertEqual(contextLoader.loadRootCallsCount, 1)

        contextLoader.completeLoad()

        await waitUntil {
            viewModel.isPlaybackContextReady
        }
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

    /// После запуска приложение восстанавливает текущий iTunes-трек вместе с полным сохранённым порядком.
    func testPurchasedITunesContextRestoresAfterRestart() async {
        let firstTrack = makePurchasedITunesTrack(id: 1, title: "Alpha")
        let middleTrack = makePurchasedITunesTrack(id: 2, title: "Middle")
        let lastTrack = makePurchasedITunesTrack(id: 3, title: "Zulu")
        let statePersistence = RestorationStatePersistenceSpy(
            state: makePurchasedITunesState(trackId: middleTrack.trackId)
        )
        let viewModel = makeViewModel(
            statePersistence: statePersistence,
            purchasedITunesContextLoader: PurchasedITunesContextLoaderSpy(
                result: .loaded([firstTrack, middleTrack, lastTrack])
            ),
            fastTrackProvider: FastLibraryTrackProviderSpy(track: nil),
            libraryAccessState: LibraryAccessState(isRestored: false)
        )

        await waitUntil {
            viewModel.isPlaybackContextReady
        }

        XCTAssertEqual(viewModel.currentTrackDisplayable?.trackId, middleTrack.trackId)
        XCTAssertTrue(viewModel.canPlayPreviousTrack)
        XCTAssertTrue(viewModel.canPlayNextTrack)
        XCTAssertEqual(statePersistence.clearCallsCount, 0)
    }

    /// Средний элемент восстановленного iTunes-порядка разрешает оба направления без открытия раздела фонотеки.
    func testPurchasedITunesMiddleTrackEnablesPreviousAndNext() async {
        let firstTrack = makePurchasedITunesTrack(id: 11, title: "Alpha")
        let middleTrack = makePurchasedITunesTrack(id: 12, title: "Middle")
        let lastTrack = makePurchasedITunesTrack(id: 13, title: "Zulu")
        let viewModel = makePurchasedITunesRestorationViewModel(
            currentTrack: middleTrack,
            context: [firstTrack, middleTrack, lastTrack]
        )

        await waitUntil {
            viewModel.isPlaybackContextReady
        }

        XCTAssertTrue(viewModel.canPlayPreviousTrack)
        XCTAssertTrue(viewModel.canPlayNextTrack)
    }

    /// Первый элемент iTunes-порядка не создаёт несуществующий переход назад.
    func testPurchasedITunesFirstTrackEnablesOnlyNext() async {
        let firstTrack = makePurchasedITunesTrack(id: 21, title: "Alpha")
        let secondTrack = makePurchasedITunesTrack(id: 22, title: "Zulu")
        let viewModel = makePurchasedITunesRestorationViewModel(
            currentTrack: firstTrack,
            context: [firstTrack, secondTrack]
        )

        await waitUntil {
            viewModel.isPlaybackContextReady
        }

        XCTAssertFalse(viewModel.canPlayPreviousTrack)
        XCTAssertTrue(viewModel.canPlayNextTrack)
    }

    /// Последний элемент iTunes-порядка не создаёт несуществующий переход вперёд.
    func testPurchasedITunesLastTrackEnablesOnlyPrevious() async {
        let firstTrack = makePurchasedITunesTrack(id: 31, title: "Alpha")
        let lastTrack = makePurchasedITunesTrack(id: 32, title: "Zulu")
        let viewModel = makePurchasedITunesRestorationViewModel(
            currentTrack: lastTrack,
            context: [firstTrack, lastTrack]
        )

        await waitUntil {
            viewModel.isPlaybackContextReady
        }

        XCTAssertTrue(viewModel.canPlayPreviousTrack)
        XCTAssertFalse(viewModel.canPlayNextTrack)
    }

    /// Восстановление готового iTunes-контекста не создаёт неявный вызов PlayerManager.play.
    func testPurchasedITunesRestorationDoesNotStartPlayback() async {
        let track = makePurchasedITunesTrack(id: 41, title: "Paused")
        let playerManager = RestorationPlayerManagerSpy()
        let viewModel = makeViewModel(
            playerManager: playerManager,
            statePersistence: RestorationStatePersistenceSpy(
                state: makePurchasedITunesState(trackId: track.trackId)
            ),
            purchasedITunesContextLoader: PurchasedITunesContextLoaderSpy(result: .loaded([track])),
            fastTrackProvider: FastLibraryTrackProviderSpy(track: nil),
            libraryAccessState: LibraryAccessState(isRestored: false)
        )

        await waitUntil {
            viewModel.isPlaybackContextReady
        }

        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertEqual(playerManager.playCallsCount, 0)
    }

    /// PlayerViewModel сохраняет порядок, уже построенный общим iTunes-сортировщиком загрузчика.
    func testPurchasedITunesRestorationUsesSavedSorting() async {
        let alphaTrack = makePurchasedITunesTrack(id: 51, title: "Alpha")
        let middleTrack = makePurchasedITunesTrack(id: 52, title: "Middle")
        let zuluTrack = makePurchasedITunesTrack(id: 53, title: "Zulu")
        let playerManager = RestorationPlayerManagerSpy()
        let viewModel = makeViewModel(
            playerManager: playerManager,
            statePersistence: RestorationStatePersistenceSpy(
                state: makePurchasedITunesState(trackId: middleTrack.trackId)
            ),
            purchasedITunesContextLoader: PurchasedITunesContextLoaderSpy(
                result: .loaded([alphaTrack, middleTrack, zuluTrack])
            ),
            fastTrackProvider: FastLibraryTrackProviderSpy(track: nil),
            libraryAccessState: LibraryAccessState(isRestored: false)
        )

        await waitUntil {
            viewModel.isPlaybackContextReady && viewModel.canPlayNextTrack
        }

        viewModel.playNextTrack()

        await waitUntil {
            playerManager.playedTrackIds == [zuluTrack.trackId]
        }

        XCTAssertEqual(viewModel.currentTrackDisplayable?.trackId, zuluTrack.trackId)
    }

    /// Успешно прочитанный список без сохранённого iTunes-трека очищает только устаревшее player_state.
    func testPurchasedITunesMissingCurrentTrackClearsRestoredState() async {
        let missingTrack = makePurchasedITunesTrack(id: 61, title: "Missing")
        let availableTrack = makePurchasedITunesTrack(id: 62, title: "Available")
        let statePersistence = RestorationStatePersistenceSpy(
            state: makePurchasedITunesState(trackId: missingTrack.trackId)
        )
        let viewModel = makeViewModel(
            statePersistence: statePersistence,
            purchasedITunesContextLoader: PurchasedITunesContextLoaderSpy(result: .loaded([availableTrack])),
            fastTrackProvider: FastLibraryTrackProviderSpy(track: nil),
            libraryAccessState: LibraryAccessState(isRestored: false)
        )

        await waitUntil {
            statePersistence.clearCallsCount == 1
        }

        XCTAssertEqual(viewModel.miniPlayerState, .empty)
        XCTAssertNil(viewModel.currentTrackDisplayable)
        XCTAssertFalse(viewModel.isPlaybackContextReady)
    }

    /// Временная недоступность MediaPlayer не выдаёт отсутствие списка за удаление сохранённого трека.
    func testPurchasedITunesTemporaryUnavailableDoesNotClearState() async {
        let track = makePurchasedITunesTrack(id: 71, title: "Deferred")
        let statePersistence = RestorationStatePersistenceSpy(
            state: makePurchasedITunesState(trackId: track.trackId)
        )
        let loader = PurchasedITunesContextLoaderSpy(result: .temporarilyUnavailable)
        let viewModel = makeViewModel(
            statePersistence: statePersistence,
            purchasedITunesContextLoader: loader,
            fastTrackProvider: FastLibraryTrackProviderSpy(track: nil),
            libraryAccessState: LibraryAccessState(isRestored: false)
        )

        await waitUntil {
            loader.loadCallsCount == 1
        }

        XCTAssertEqual(statePersistence.clearCallsCount, 0)
        XCTAssertNil(viewModel.currentTrackDisplayable)
        XCTAssertFalse(viewModel.isPlaybackContextReady)
        XCTAssertEqual(viewModel.miniPlayerState, .loading(staticState: nil))

        loader.setResult(.loaded([track]))
        NotificationCenter.default.post(
            name: .purchasedITunesMediaLibraryAccessDidChange,
            object: nil
        )

        await waitUntil {
            viewModel.isPlaybackContextReady && loader.loadCallsCount == 2
        }

        XCTAssertEqual(statePersistence.clearCallsCount, 0)
        XCTAssertEqual(viewModel.currentTrackDisplayable?.trackId, track.trackId)
    }

    /// Запрет MediaPlayer оставляет iTunes-восстановление отдельным от fallback очереди и не запускает навигацию.
    func testPurchasedITunesDeniedAccessDoesNotFallbackToPlayerQueue() async {
        let track = makePurchasedITunesTrack(id: 81, title: "Denied")
        let statePersistence = RestorationStatePersistenceSpy(
            state: makePurchasedITunesState(trackId: track.trackId)
        )
        let loader = PurchasedITunesContextLoaderSpy(result: .accessDenied)
        let playerManager = RestorationPlayerManagerSpy()
        let viewModel = makeViewModel(
            playerManager: playerManager,
            statePersistence: statePersistence,
            purchasedITunesContextLoader: loader,
            fastTrackProvider: FastLibraryTrackProviderSpy(track: nil),
            libraryAccessState: LibraryAccessState(isRestored: false)
        )

        await waitUntil {
            loader.loadCallsCount == 1
        }

        viewModel.playNextTrack()

        XCTAssertEqual(statePersistence.clearCallsCount, 0)
        XCTAssertTrue(statePersistence.savedContextSources.isEmpty)
        XCTAssertNil(viewModel.currentTrackDisplayable)
        XCTAssertFalse(viewModel.isPlaybackContextReady)
        XCTAssertEqual(playerManager.playCallsCount, 0)
    }

    /// Поздний результат iTunes-загрузчика не возвращает старый контекст после ручного выбора другого трека.
    func testStalePurchasedITunesRestorationDoesNotReplaceUserSelection() async {
        let restoredTrack = makePurchasedITunesTrack(id: 91, title: "Restored")
        let selectedTrack = makeLibraryTrack(fileName: "Selected.m4a")
        let contextLoader = PurchasedITunesContextLoaderSpy(
            result: .loaded([restoredTrack]),
            delaysFirstLoad: true
        )
        let viewModel = makeViewModel(
            statePersistence: RestorationStatePersistenceSpy(
                state: makePurchasedITunesState(trackId: restoredTrack.trackId)
            ),
            purchasedITunesContextLoader: contextLoader,
            fastTrackProvider: FastLibraryTrackProviderSpy(track: nil),
            libraryAccessState: LibraryAccessState(isRestored: false)
        )

        await waitUntil {
            contextLoader.loadCallsCount == 1
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
        XCTAssertEqual(viewModel.currentContext, .library)
    }

    /// Переход Next сохраняет iTunes-источник, чтобы следующий запуск снова загрузил системный порядок.
    func testPurchasedITunesSourcePersistsAfterNext() async {
        let firstTrack = makePurchasedITunesTrack(id: 101, title: "Alpha")
        let secondTrack = makePurchasedITunesTrack(id: 102, title: "Zulu")
        let statePersistence = RestorationStatePersistenceSpy(
            state: makePurchasedITunesState(trackId: firstTrack.trackId)
        )
        let playerManager = RestorationPlayerManagerSpy()
        let viewModel = makeViewModel(
            playerManager: playerManager,
            statePersistence: statePersistence,
            purchasedITunesContextLoader: PurchasedITunesContextLoaderSpy(
                result: .loaded([firstTrack, secondTrack])
            ),
            fastTrackProvider: FastLibraryTrackProviderSpy(track: nil),
            libraryAccessState: LibraryAccessState(isRestored: false)
        )

        await waitUntil {
            viewModel.isPlaybackContextReady && viewModel.canPlayNextTrack
        }

        viewModel.playNextTrack()

        await waitUntil {
            playerManager.playedTrackIds == [secondTrack.trackId]
        }

        XCTAssertEqual(statePersistence.savedContextSources.last, .purchasedITunes)
    }

    /// Переход Previous сохраняет iTunes-источник, не превращая восстановленный порядок в очередь плеера.
    func testPurchasedITunesSourcePersistsAfterPrevious() async {
        let firstTrack = makePurchasedITunesTrack(id: 111, title: "Alpha")
        let lastTrack = makePurchasedITunesTrack(id: 112, title: "Zulu")
        let statePersistence = RestorationStatePersistenceSpy(
            state: makePurchasedITunesState(trackId: lastTrack.trackId)
        )
        let playerManager = RestorationPlayerManagerSpy()
        let viewModel = makeViewModel(
            playerManager: playerManager,
            statePersistence: statePersistence,
            purchasedITunesContextLoader: PurchasedITunesContextLoaderSpy(
                result: .loaded([firstTrack, lastTrack])
            ),
            fastTrackProvider: FastLibraryTrackProviderSpy(track: nil),
            libraryAccessState: LibraryAccessState(isRestored: false)
        )

        await waitUntil {
            viewModel.isPlaybackContextReady && viewModel.canPlayPreviousTrack
        }

        viewModel.playPreviousTrack()

        await waitUntil {
            playerManager.playedTrackIds == [firstTrack.trackId]
        }

        XCTAssertEqual(statePersistence.savedContextSources.last, .purchasedITunes)
    }

    /// Общий play-маршрут распознаёт iTunes runtime-контекст по TrackSource и сохраняет его без специального метода воспроизведения.
    func testSharedPlayDetectsPurchasedITunesContextSource() {
        let firstTrack = makePurchasedITunesTrack(id: 121, title: "Alpha")
        let secondTrack = makePurchasedITunesTrack(id: 122, title: "Zulu")
        let statePersistence = RestorationStatePersistenceSpy(state: nil)
        let viewModel = makeViewModel(
            statePersistence: statePersistence,
            fastTrackProvider: FastLibraryTrackProviderSpy(track: nil),
            libraryAccessState: LibraryAccessState(isRestored: false)
        )

        viewModel.play(track: firstTrack, context: [firstTrack, secondTrack])

        XCTAssertEqual(statePersistence.savedContextSources.last, .purchasedITunes)
    }

    /// Прямой запуск Purchased iTunes сохраняет тот же runtime-идентификатор и не создаёт идентификатор очереди.
    func testPlayingPurchasedITunesTrackPersistsItsTrackIdAndSource() {
        let firstTrack = makePurchasedITunesTrack(id: 131, title: "Alpha")
        let secondTrack = makePurchasedITunesTrack(id: 132, title: "Zulu")
        let statePersistence = RestorationStatePersistenceSpy(state: nil)
        let viewModel = makeViewModel(
            statePersistence: statePersistence,
            fastTrackProvider: FastLibraryTrackProviderSpy(track: nil),
            libraryAccessState: LibraryAccessState(isRestored: false)
        )

        viewModel.play(track: firstTrack, context: [firstTrack, secondTrack])

        let savedWrite = statePersistence.savedWrites.last
        XCTAssertEqual(savedWrite?.trackId, firstTrack.trackId)
        XCTAssertEqual(savedWrite?.source, .purchasedITunes)
        XCTAssertNil(savedWrite?.queueItemId)
        XCTAssertEqual(savedWrite?.duration, firstTrack.duration)
    }

    /// Событие готовности локальной фонотеки не запускает её восстановление поверх сохранённого Purchased iTunes.
    func testPurchasedITunesRestorationIsNotReplacedByLastLibraryTrack() async {
        let purchasedTrack = makePurchasedITunesTrack(id: 141, title: "Purchased")
        let lastLibraryTrack = makeLibraryTrack(fileName: "Last Local.m4a")
        let accessState = LibraryAccessState(isRestored: false)
        let purchasedLoader = PurchasedITunesContextLoaderSpy(
            result: .loaded([purchasedTrack]),
            delaysFirstLoad: true
        )
        let libraryLoader = LibraryContextLoaderSpy(tracks: [lastLibraryTrack])
        let viewModel = makeViewModel(
            statePersistence: RestorationStatePersistenceSpy(
                state: makePurchasedITunesState(trackId: purchasedTrack.trackId)
            ),
            libraryContextLoader: libraryLoader,
            purchasedITunesContextLoader: purchasedLoader,
            fastTrackProvider: FastLibraryTrackProviderSpy(track: lastLibraryTrack),
            libraryAccessState: accessState
        )

        await waitUntil {
            purchasedLoader.loadCallsCount == 1
        }

        accessState.isRestored = true
        NotificationCenter.default.post(name: .libraryAccessRestored, object: nil)
        await Task.yield()

        XCTAssertEqual(libraryLoader.loadRootCallsCount, 0)

        purchasedLoader.completeLoad()
        await waitUntil {
            viewModel.currentTrackDisplayable?.trackId == purchasedTrack.trackId
        }

        NotificationCenter.default.post(name: .libraryAccessRestored, object: nil)
        await Task.yield()

        XCTAssertEqual(viewModel.currentTrackDisplayable?.trackId, purchasedTrack.trackId)
        XCTAssertEqual(viewModel.currentContext, .purchasedITunes)
    }

    /// Поздний local-контекст не может примениться после ручного выбора Purchased iTunes.
    func testLateLibraryRestorationCannotReplacePurchasedITunesTrack() async {
        let lastLibraryTrack = makeLibraryTrack(fileName: "Last Local.m4a")
        let purchasedTrack = makePurchasedITunesTrack(id: 151, title: "Purchased")
        let accessState = LibraryAccessState(isRestored: false)
        let libraryLoader = DelayedLibraryContextLoaderSpy(tracks: [lastLibraryTrack])
        let viewModel = makeViewModel(
            statePersistence: RestorationStatePersistenceSpy(
                state: makeLibraryState(trackId: lastLibraryTrack.trackId)
            ),
            libraryContextLoader: libraryLoader,
            fastTrackProvider: FastLibraryTrackProviderSpy(track: lastLibraryTrack),
            libraryAccessState: accessState
        )

        await waitUntil {
            viewModel.isPlaybackContextReady
        }

        accessState.isRestored = true
        NotificationCenter.default.post(name: .libraryAccessRestored, object: nil)
        await waitUntil {
            libraryLoader.loadRootCallsCount == 2
        }

        viewModel.play(track: purchasedTrack, context: [purchasedTrack])
        await waitUntil {
            viewModel.currentTrackDisplayable?.trackId == purchasedTrack.trackId
        }

        libraryLoader.completeLoad()
        await Task.yield()

        XCTAssertEqual(viewModel.currentTrackDisplayable?.trackId, purchasedTrack.trackId)
        XCTAssertEqual(viewModel.currentContext, .purchasedITunes)
    }

    /// Собирает ViewModel только с изолированными зависимостями, чтобы тесты не обращались к SQLite, bookmark и AVPlayer.
    private func makeViewModel(
        playerManager: RestorationPlayerManagerSpy = RestorationPlayerManagerSpy(),
        eventObserver: RestorationPlayerEventObserverSpy? = nil,
        statePersistence: RestorationStatePersistenceSpy,
        libraryContextLoader: (any LibraryPlaybackContextLoading)? = nil,
        purchasedITunesContextLoader: (any PurchasedITunesPlaybackContextLoading)? = nil,
        fastTrackProvider: any FastLibraryTrackProviding,
        libraryAccessState: LibraryAccessState
    ) -> PlayerViewModel {
        let resolvedLibraryContextLoader = libraryContextLoader ?? LibraryContextLoaderSpy(tracks: [])
        let resolvedPurchasedITunesContextLoader = purchasedITunesContextLoader ??
            PurchasedITunesContextLoaderSpy(result: .temporarilyUnavailable)
        let favoritesService = PlayerFavoritesServiceSpy()

        return PlayerViewModel(
            playerManager: playerManager,
            playbackContextStore: PlayerPlaybackContextStore(
                playbackModePersistence: RestorationPlaybackModePersistenceSpy()
            ),
            runtimeSnapshotController: PlayerRuntimeSnapshotController(),
            eventObserver: eventObserver ?? RestorationPlayerEventObserverSpy(),
            toastPresenter: RestorationToastPresenterSpy(),
            statePersistence: statePersistence,
            playlistManager: PlaylistManager(
                databaseStore: RestorationPlayerQueuePersistenceSpy(),
                loadsInitialQueue: false
            ),
            libraryContextLoader: resolvedLibraryContextLoader,
            purchasedITunesContextLoader: resolvedPurchasedITunesContextLoader,
            fastLibraryTrackProvider: fastTrackProvider,
            isLibraryAccessRestored: { libraryAccessState.isRestored },
            waveformGenerator: RestorationWaveformGeneratorSpy(),
            favoritesService: favoritesService,
            favoriteActionHandler: FavoriteTrackActionHandler(
                favoritesService: favoritesService
            ),
            favoritesEvents: PlayerFavoritesEventsSubject()
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

    /// Формирует сохранённое состояние iTunes без очереди и локального bookmark-контекста.
    private func makePurchasedITunesState(trackId: UUID) -> PlayerStateDatabaseModel {
        PlayerStateDatabaseModel(
            id: 1,
            currentQueueItemId: nil,
            currentTrackId: trackId,
            contextType: .purchasedITunes,
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

    /// Создаёт PlayerViewModel для восстановленного iTunes-порядка без доступа к системной медиатеке.
    private func makePurchasedITunesRestorationViewModel(
        currentTrack: PurchasedITunesPlayableTrack,
        context: [PurchasedITunesPlayableTrack]
    ) -> PlayerViewModel {
        makeViewModel(
            statePersistence: RestorationStatePersistenceSpy(
                state: makePurchasedITunesState(trackId: currentTrack.trackId)
            ),
            purchasedITunesContextLoader: PurchasedITunesContextLoaderSpy(result: .loaded(context)),
            fastTrackProvider: FastLibraryTrackProviderSpy(track: nil),
            libraryAccessState: LibraryAccessState(isRestored: false)
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

    /// Создаёт runtime-адаптер с тем же стабильным UUID.v5, который production-код строит из persistentID MediaPlayer.
    private func makePurchasedITunesTrack(
        id: UInt64,
        title: String
    ) -> PurchasedITunesPlayableTrack {
        PurchasedITunesPlayableTrack(
            track: PurchasedITunesTrack(
                id: id,
                title: title,
                artist: "Artist",
                album: "Album",
                year: nil,
                genre: nil,
                dateAdded: Date(timeIntervalSince1970: 0),
                artworkData: nil,
                duration: 180,
                assetURL: URL(fileURLWithPath: "/tmp/purchased-\(id).m4a")
            )
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
    private(set) var savedContextSources: [PlaybackContextSource] = []
    private(set) var savedWrites: [SavedPlayerStateWrite] = []

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
    ) throws {
        savedContextSources.append(contextSource)
        savedWrites.append(
            SavedPlayerStateWrite(
                trackId: trackId,
                queueItemId: queueItemId,
                duration: duration,
                source: contextSource
            )
        )
    }

    func clearState() throws {
        clearCallsCount += 1
        state = nil
    }
}

/// Сохраняет параметры одной записи spy, чтобы проверять инвариант trackId и источника без SQLite.
private struct SavedPlayerStateWrite {
    let trackId: UUID
    let queueItemId: UUID?
    let duration: TimeInterval
    let source: PlaybackContextSource
}

/// Исключает файловый waveform pipeline в тестах восстановления состояния плеера.
private actor RestorationWaveformGeneratorSpy: WaveformGenerating {
    func generateSamples(
        from fileURL: URL,
        sampleCount: Int
    ) async throws -> [Double] { [] }
}

/// Возвращает управляемый результат загрузки iTunes-контекста и может задержать первый ответ для проверки устаревшей асинхронной операции.
@MainActor
private final class PurchasedITunesContextLoaderSpy: PurchasedITunesPlaybackContextLoading {
    private var result: PurchasedITunesPlaybackContextLoadResult
    private let delaysFirstLoad: Bool
    private var loadContinuation: CheckedContinuation<PurchasedITunesPlaybackContextLoadResult, Never>?
    private(set) var loadCallsCount = 0

    init(
        result: PurchasedITunesPlaybackContextLoadResult,
        delaysFirstLoad: Bool = false
    ) {
        self.result = result
        self.delaysFirstLoad = delaysFirstLoad
    }

    func loadPlaybackContext() async -> PurchasedITunesPlaybackContextLoadResult {
        loadCallsCount += 1

        guard delaysFirstLoad, loadCallsCount == 1 else {
            return result
        }

        return await withCheckedContinuation { continuation in
            loadContinuation = continuation
        }
    }

    /// Завершает первую удерживаемую загрузку тем же результатом, который был задан для теста.
    func completeLoad() {
        loadContinuation?.resume(returning: result)
        loadContinuation = nil
    }

    /// Меняет следующий ответ, чтобы проверить повторную попытку только после события готовности MediaPlayer.
    func setResult(_ result: PurchasedITunesPlaybackContextLoadResult) {
        self.result = result
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

/// Возвращает контексты по порядку запросов, чтобы проверить замену предварительного состояния окончательным.
@MainActor
private final class SequencedLibraryContextLoaderSpy: LibraryPlaybackContextLoading {
    private let contexts: [[LibraryTrack]]
    private(set) var loadRootCallsCount = 0

    init(contexts: [[LibraryTrack]]) {
        self.contexts = contexts
    }

    func loadFolderContext(folderId: UUID) async throws -> [LibraryTrack] {
        []
    }

    func loadRootContext() async throws -> [LibraryTrack] {
        let contextIndex = min(loadRootCallsCount, contexts.count - 1)
        loadRootCallsCount += 1
        return contexts[contextIndex]
    }

    func loadCollectionContext(
        category: LibraryCollectionCategory,
        rawValue: String,
        artistKey: String?
    ) async throws -> [LibraryTrack] {
        []
    }
}

/// Удерживает выбранную загрузку контекста до явного завершения, чтобы проверить приоритет пользовательского выбора и защиту от параллельных запросов.
@MainActor
private final class DelayedLibraryContextLoaderSpy: LibraryPlaybackContextLoading {
    private let tracks: [LibraryTrack]
    private let delayedLoadNumber: Int
    private var loadContinuation: CheckedContinuation<[LibraryTrack], Never>?
    private(set) var loadRootCallsCount = 0

    init(
        tracks: [LibraryTrack],
        delaysFirstLoad: Bool = false
    ) {
        self.tracks = tracks
        self.delayedLoadNumber = delaysFirstLoad ? 1 : 2
    }

    func loadFolderContext(folderId: UUID) async throws -> [LibraryTrack] {
        []
    }

    func loadRootContext() async throws -> [LibraryTrack] {
        loadRootCallsCount += 1

        guard loadRootCallsCount == delayedLoadNumber else {
            return tracks
        }

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
