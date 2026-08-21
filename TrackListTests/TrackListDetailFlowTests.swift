//
//  TrackListDetailFlowTests.swift
//  TrackList
//
//  Контракты detail-flow треклиста: загрузка, invalidation и presentation state.
//
//  Created by Pavel Fomin on 13.08.2026.
//

import Combine
import Foundation
import UIKit
import XCTest
@testable import TrackList

/// Проверяет наблюдаемое поведение detail-flow без SQLite, singleton-ов и SwiftUI View.
@MainActor
final class TrackListDetailFlowTests: XCTestCase {

    /// Успешная initial-загрузка публикует полный ScreenState для immutable route ID.
    func testInitialLoadSuccessPublishesLoadedScreenState() async {
        let trackListId = UUID()
        let track = makeTrack(fileName: "Initial.flac")
        let fixture = makeFixture(
            trackListId: trackListId,
            outcomes: [.success(makeTrackList(id: trackListId, tracks: [track]))]
        )

        fixture.viewModel.loadIfNeeded()
        await yieldToDetailTasks()

        let state = tryLoadedState(from: fixture.viewModel)
        XCTAssertEqual(state?.id, trackListId)
        XCTAssertEqual(state?.rows.map(\.id), [track.id])
        XCTAssertEqual(fixture.loader.loadCallCount, 1)
    }

    /// Typed screen lifecycle запускает initial read только один раз для detail destination.
    func testScreenAppearedActionStartsInitialDetailReadOnlyOnce() async {
        let trackListId = UUID()
        let fixture = makeFixture(
            trackListId: trackListId,
            outcomes: [.success(makeTrackList(id: trackListId, tracks: []))]
        )
        let actionHandler = makeFlowActionHandler(for: fixture.viewModel)

        actionHandler.handle(.screenAppeared)
        actionHandler.handle(.screenAppeared)
        await yieldToDetailTasks()

        XCTAssertEqual(fixture.loader.loadCallCount, 1)
        XCTAssertEqual(tryLoadedState(from: fixture.viewModel)?.id, trackListId)
    }

    /// Typed retry повторяет initial read после failure, но не перезагружает уже согласованный detail.
    func testRetryInitialLoadActionRetriesFailureButNotSuccessfulDetail() async {
        let trackListId = UUID()
        let fixture = makeFixture(
            trackListId: trackListId,
            outcomes: [
                .failure(AppError.trackListLoadFailed),
                .success(makeTrackList(id: trackListId, tracks: []))
            ]
        )
        let actionHandler = makeFlowActionHandler(for: fixture.viewModel)

        actionHandler.handle(.screenAppeared)
        actionHandler.handle(.retryInitialLoad)
        await yieldToDetailTasks()

        XCTAssertEqual(fixture.loader.loadCallCount, 2)
        XCTAssertEqual(tryLoadedState(from: fixture.viewModel)?.id, trackListId)

        actionHandler.handle(.retryInitialLoad)
        await yieldToDetailTasks()

        XCTAssertEqual(fixture.loader.loadCallCount, 2)
    }

    /// Typed initial lifecycle сохраняет самостоятельное not-found presentation state detail route.
    func testScreenAppearedActionPreservesNotFoundState() async {
        let fixture = makeFixture(outcomes: [.failure(AppError.trackListNotFound)])
        let actionHandler = makeFlowActionHandler(for: fixture.viewModel)

        actionHandler.handle(.screenAppeared)
        await yieldToDetailTasks()

        guard case .notFound = fixture.viewModel.content else {
            return XCTFail("Ожидалось состояние notFound")
        }
        XCTAssertEqual(fixture.loader.loadCallCount, 1)
    }

    /// Корректно пустой треклист остаётся loaded, а не маскируется под loading или failure.
    func testInitialLoadEmptyTrackListPublishesLoadedEmptyState() async {
        let trackListId = UUID()
        let fixture = makeFixture(
            trackListId: trackListId,
            outcomes: [.success(makeTrackList(id: trackListId, tracks: []))]
        )

        fixture.viewModel.loadIfNeeded()
        await yieldToDetailTasks()

        XCTAssertTrue(tryLoadedState(from: fixture.viewModel)?.rows.isEmpty == true)
    }

    /// Несуществующий route ID получает самостоятельное not-found состояние.
    func testInitialLoadNotFoundPublishesNotFoundState() async {
        let fixture = makeFixture(
            outcomes: [.failure(AppError.trackListNotFound)]
        )

        fixture.viewModel.loadIfNeeded()
        await yieldToDetailTasks()

        guard case .notFound = fixture.viewModel.content else {
            return XCTFail("Ожидалось состояние notFound")
        }
        XCTAssertEqual(fixture.toastPresenter.errors, [.trackListNotFound])
    }

    /// Ошибка initial read не превращается в визуально пустой треклист.
    func testInitialLoadFailurePublishesRetryableFailureState() async {
        let fixture = makeFixture(
            outcomes: [.failure(AppError.trackListLoadFailed)]
        )

        fixture.viewModel.loadIfNeeded()
        await yieldToDetailTasks()

        guard case .failed = fixture.viewModel.content else {
            return XCTFail("Ожидалось состояние failed")
        }
        XCTAssertEqual(fixture.toastPresenter.errors, [.trackListLoadFailed])
    }

    /// Retry после initial failure повторно читает именно тот же detail ID.
    func testRetryAfterInitialFailurePublishesLoadedState() async {
        let trackListId = UUID()
        let track = makeTrack(fileName: "Retried.flac")
        let fixture = makeFixture(
            trackListId: trackListId,
            outcomes: [
                .failure(AppError.trackListLoadFailed),
                .success(makeTrackList(id: trackListId, tracks: [track]))
            ]
        )

        fixture.viewModel.loadIfNeeded()
        fixture.viewModel.retryInitialLoad()
        await yieldToDetailTasks()

        XCTAssertEqual(tryLoadedState(from: fixture.viewModel)?.rows.map(\.trackId), [track.trackId])
        XCTAssertEqual(fixture.loader.loadCallCount, 2)
    }

    /// Invalidation состава заменяет detail только успешным полным snapshot-ом.
    func testTrackListTracksChangeReloadsDetailWithNewSnapshot() async {
        let trackListId = UUID()
        let oldTrack = makeTrack(fileName: "Old.flac")
        let newTrack = makeTrack(fileName: "New.flac")
        let fixture = makeFixture(
            trackListId: trackListId,
            outcomes: [
                .success(makeTrackList(id: trackListId, tracks: [oldTrack])),
                .success(makeTrackList(id: trackListId, tracks: [newTrack]))
            ]
        )

        fixture.viewModel.loadIfNeeded()
        await yieldToDetailTasks()
        fixture.events.trackListTracksSubject.send(trackListId)
        await yieldToDetailTasks()

        XCTAssertEqual(tryLoadedState(from: fixture.viewModel)?.rows.map(\.trackId), [newTrack.trackId])
        XCTAssertEqual(fixture.loader.loadCallCount, 2)
    }

    /// Ошибка reload сохраняет последний корректный ScreenState вместо ложного «No Tracks».
    func testReloadFailureKeepsPreviouslyLoadedTracks() async {
        let trackListId = UUID()
        let track = makeTrack(fileName: "Preserved.flac")
        let fixture = makeFixture(
            trackListId: trackListId,
            outcomes: [
                .success(makeTrackList(id: trackListId, tracks: [track])),
                .failure(AppError.trackListLoadFailed)
            ]
        )

        fixture.viewModel.loadIfNeeded()
        await yieldToDetailTasks()
        fixture.events.trackListTracksSubject.send(trackListId)
        await yieldToDetailTasks()

        XCTAssertEqual(tryLoadedState(from: fixture.viewModel)?.rows.map(\.id), [track.id])
        XCTAssertEqual(fixture.toastPresenter.errors, [.trackListLoadFailed])
    }

    /// Публикатор Favorites имеет приоритет над намеренно устаревшим synchronous property провайдера.
    func testFavoritesUsesEmittedSnapshotWhenProviderPropertyIsStale() async {
        let trackListId = UUID()
        let track = makeTrack(fileName: "Favorite.flac")
        let favorites = DetailFavoritesProvider(storedIds: [])
        let fixture = makeFixture(
            trackListId: trackListId,
            outcomes: [.success(makeTrackList(id: trackListId, tracks: [track]))],
            favorites: favorites
        )

        fixture.viewModel.loadIfNeeded()
        await yieldToDetailTasks()
        favorites.emitWithoutChangingStoredProperty([track.trackId])
        await yieldToDetailTasks()

        XCTAssertTrue(tryLoadedState(from: fixture.viewModel)?.rows.first?.isFavorite == true)
        XCTAssertTrue(favorites.favoriteTrackIds.isEmpty)
    }

    /// Playback publisher использует emitted snapshot и сопоставляет текущую строку по Track.id, а не trackId.
    func testPlaybackUsesEmittedDisplayableRowIdentity() async {
        let trackListId = UUID()
        let physicalTrackId = UUID()
        let firstRow = makeTrack(trackId: physicalTrackId, fileName: "First.flac")
        let secondRow = makeTrack(trackId: physicalTrackId, fileName: "Second.flac")
        let playback = DetailPlaybackProvider()
        let fixture = makeFixture(
            trackListId: trackListId,
            outcomes: [.success(makeTrackList(id: trackListId, tracks: [firstRow, secondRow]))],
            playback: playback
        )

        fixture.viewModel.loadIfNeeded()
        await yieldToDetailTasks()
        playback.emit(
            PlaybackStateSnapshot(
                currentDisplayableId: secondRow.id,
                currentTrackId: physicalTrackId,
                currentContext: .trackList,
                currentContextSource: .trackList(id: trackListId),
                isPlaying: true
            )
        )
        await yieldToDetailTasks()

        let rows = tryLoadedState(from: fixture.viewModel)?.rows ?? []
        XCTAssertEqual(rows.map(\.isCurrent), [false, true])
        XCTAssertEqual(rows.map(\.isPlaying), [false, true])
    }

    /// Повторный lifecycle request не создаёт второй runtime build одного physical track ID.
    func testRuntimeSnapshotRequestIsDeduplicatedPerPhysicalTrackID() async {
        let trackListId = UUID()
        let track = makeTrack(fileName: "Deduplicated.flac")
        let snapshotBuilder = ControlledRuntimeSnapshotBuilder()
        let fixture = makeFixture(
            trackListId: trackListId,
            outcomes: [.success(makeTrackList(id: trackListId, tracks: [track]))],
            snapshotBuilder: snapshotBuilder
        )

        fixture.viewModel.loadIfNeeded()
        fixture.viewModel.requestSnapshotIfNeeded(for: track.trackId)
        fixture.viewModel.requestSnapshotIfNeeded(for: track.trackId)
        await yieldToDetailTasks()

        let requestCount = await snapshotBuilder.requestCount(for: track.trackId)
        XCTAssertEqual(requestCount, 1)
    }

    /// Каноничный TrackUpdateEvent отменяет старый build и не даёт ему затереть более новый snapshot.
    func testRuntimeSnapshotLateBuildDoesNotOverwriteTrackUpdateEvent() async {
        let trackListId = UUID()
        let track = makeTrack(fileName: "Original.flac")
        let snapshotBuilder = ControlledRuntimeSnapshotBuilder()
        let fixture = makeFixture(
            trackListId: trackListId,
            outcomes: [.success(makeTrackList(id: trackListId, tracks: [track]))],
            snapshotBuilder: snapshotBuilder
        )

        fixture.viewModel.loadIfNeeded()
        fixture.viewModel.requestSnapshotIfNeeded(for: track.trackId)
        await yieldToDetailTasks()
        fixture.events.trackDidUpdateSubject.send(
            TrackUpdateEvent(
                trackId: track.trackId,
                reason: .metadataUpdated,
                changedFields: [.title],
                snapshot: makeSnapshot(trackId: track.trackId, title: "Canonical")
            )
        )
        await yieldToDetailTasks()
        await snapshotBuilder.completeNext(
            for: track.trackId,
            with: makeSnapshot(trackId: track.trackId, title: "Late")
        )
        await yieldToDetailTasks()

        XCTAssertEqual(tryLoadedState(from: fixture.viewModel)?.rows.first?.title, "Canonical")
    }

    /// Удалённая строка не принимает поздний runtime snapshot от уже отменённой задачи.
    func testRemovedTrackDoesNotReceiveLateRuntimeSnapshot() async {
        let trackListId = UUID()
        let removedTrack = makeTrack(fileName: "Removed.flac")
        let snapshotBuilder = ControlledRuntimeSnapshotBuilder()
        let fixture = makeFixture(
            trackListId: trackListId,
            outcomes: [
                .success(makeTrackList(id: trackListId, tracks: [removedTrack])),
                .success(makeTrackList(id: trackListId, tracks: []))
            ],
            snapshotBuilder: snapshotBuilder
        )

        fixture.viewModel.loadIfNeeded()
        fixture.viewModel.requestSnapshotIfNeeded(for: removedTrack.trackId)
        await yieldToDetailTasks()
        fixture.events.trackListTracksSubject.send(trackListId)
        await yieldToDetailTasks()
        await snapshotBuilder.completeNext(
            for: removedTrack.trackId,
            with: makeSnapshot(trackId: removedTrack.trackId, title: "Late")
        )
        await yieldToDetailTasks()

        XCTAssertTrue(tryLoadedState(from: fixture.viewModel)?.rows.isEmpty == true)
    }

    /// Изменение tag-reading инвалидирует старый runtime build и публикует только новый результат.
    func testSettingsInvalidationMakesOldRuntimeBuildStale() async {
        let trackListId = UUID()
        let track = makeTrack(fileName: "Settings.flac")
        let snapshotBuilder = ControlledRuntimeSnapshotBuilder()
        let settings = DetailSettingsManager()
        let fixture = makeFixture(
            trackListId: trackListId,
            outcomes: [.success(makeTrackList(id: trackListId, tracks: [track]))],
            settings: settings,
            snapshotBuilder: snapshotBuilder
        )

        fixture.viewModel.loadIfNeeded()
        fixture.viewModel.requestSnapshotIfNeeded(for: track.trackId)
        await yieldToDetailTasks()
        settings.setTagReadingEnabled(false)
        fixture.events.appSettingsDidChangeSubject.send(())
        await yieldToDetailTasks()
        await snapshotBuilder.completeNext(
            for: track.trackId,
            with: makeSnapshot(trackId: track.trackId, title: "Old")
        )
        await snapshotBuilder.completeNext(
            for: track.trackId,
            with: makeSnapshot(trackId: track.trackId, title: "New")
        )
        await yieldToDetailTasks()

        let requestCount = await snapshotBuilder.requestCount(for: track.trackId)
        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(tryLoadedState(from: fixture.viewModel)?.rows.first?.fileName, "New.flac")
    }

    /// Event постороннего physical track не пересобирает detail snapshot текущего треклиста.
    func testUnrelatedTrackUpdateDoesNotChangeDetailState() async {
        let trackListId = UUID()
        let track = makeTrack(fileName: "Relevant.flac")
        let fixture = makeFixture(
            trackListId: trackListId,
            outcomes: [.success(makeTrackList(id: trackListId, tracks: [track]))]
        )

        fixture.viewModel.loadIfNeeded()
        await yieldToDetailTasks()
        fixture.events.trackDidUpdateSubject.send(
            TrackUpdateEvent(
                trackId: UUID(),
                reason: .metadataUpdated,
                changedFields: [.title],
                snapshot: makeSnapshot(trackId: UUID(), title: "Unrelated")
            )
        )
        await yieldToDetailTasks()

        XCTAssertEqual(tryLoadedState(from: fixture.viewModel)?.rows.first?.fileName, track.fileName)
    }

    /// Неудачный summary reload сохраняет последний успешно показанный summary.
    func testSummaryReloadFailureKeepsLastSuccessfulSummary() async {
        let trackListId = UUID()
        let summary = TrackCollectionSummary(
            trackCount: 1,
            totalDuration: 120,
            totalFileSize: 1_024,
            unknownDurationCount: 0,
            unknownFileSizeCount: 0
        )
        let summaries = DetailSummaryProvider(
            outcomes: [.success(summary), .failure(DetailTestError.failed)]
        )
        let fixture = makeFixture(
            trackListId: trackListId,
            outcomes: [.success(makeTrackList(id: trackListId, tracks: [makeTrack()]))],
            summaryProvider: summaries
        )

        fixture.viewModel.loadIfNeeded()
        await yieldToDetailTasks()
        fixture.events.libraryDataDidChangeSubject.send(())
        await yieldToDetailTasks()

        XCTAssertEqual(tryLoadedState(from: fixture.viewModel)?.summary, summary)
    }

    /// Mutation handler передаёт delete command с row identity и detail route ID.
    func testDeleteRowCallsDomainCommandWithRowAndTrackListIDs() async {
        let trackListId = UUID()
        let track = makeTrack(
            fileName: "Purchased.m4a",
            source: .purchasedITunes,
            assetURL: URL(fileURLWithPath: "/tmp/Purchased.m4a")
        )
        let commandExecutor = DetailTrackListCommandSpy(result: .success(track))
        let handler = TrackListMutationHandler(
            reader: DetailReaderSpy(trackListId: trackListId, tracks: [track]),
            trackListManager: DetailTrackListManagerSpy(),
            commandExecutor: commandExecutor,
            toastPresenter: DetailToastPresenter()
        )

        handler.deleteTrack(rowId: track.id)
        await yieldToDetailTasks()

        XCTAssertEqual(commandExecutor.requests.map(\.listItemId), [track.id])
        XCTAssertEqual(commandExecutor.requests.map(\.trackListId), [trackListId])
    }

    /// Reorder сохраняет новый порядок один раз и не владеет локальным ScreenState.
    func testManualReorderPersistsCorrectOrder() {
        let trackListId = UUID()
        let first = makeTrack(fileName: "First.flac")
        let second = makeTrack(fileName: "Second.flac")
        let third = makeTrack(fileName: "Third.flac")
        let manager = DetailTrackListManagerSpy()
        let handler = TrackListMutationHandler(
            reader: DetailReaderSpy(trackListId: trackListId, tracks: [first, second, third]),
            trackListManager: manager,
            commandExecutor: DetailTrackListCommandSpy(result: .failure(AppError.trackListSaveFailed)),
            toastPresenter: DetailToastPresenter()
        )

        handler.moveTrack(from: IndexSet(integer: 0), to: 3)

        XCTAssertEqual(manager.savedTrackIds, [[second.id, third.id, first.id]])
        XCTAssertEqual(manager.savedTrackListIds, [trackListId])
    }

    /// Ошибка reorder не публикует ложный новый state: manager отвергает сохранение, reader не меняется.
    func testManualReorderFailureDoesNotChangeReaderSnapshot() {
        let first = makeTrack(fileName: "First.flac")
        let second = makeTrack(fileName: "Second.flac")
        let reader = DetailReaderSpy(trackListId: UUID(), tracks: [first, second])
        let manager = DetailTrackListManagerSpy(shouldSave: false)
        let toast = DetailToastPresenter()
        let handler = TrackListMutationHandler(
            reader: reader,
            trackListManager: manager,
            commandExecutor: DetailTrackListCommandSpy(result: .failure(AppError.trackListSaveFailed)),
            toastPresenter: toast
        )

        handler.moveTrack(from: IndexSet(integer: 0), to: 2)

        XCTAssertEqual(reader.tracks.map(\.id), [first.id, second.id])
        XCTAssertEqual(manager.savedTrackIds, [[second.id, first.id]])
        XCTAssertEqual(toast.errors, [.trackListSaveFailed])
    }

    /// Capability builder переносит policy из View и скрывает collection actions без подготовленной цели.
    func testScreenStateCapabilitiesRespectSourceAndPreparedCollectionTarget() {
        let libraryTrack = makeTrack(fileName: "Library.flac")
        let purchasedTrack = makeTrack(
            fileName: "Purchased.m4a",
            source: .purchasedITunes,
            assetURL: URL(fileURLWithPath: "/tmp/Purchased.m4a")
        )
        let target = TrackCollectionNavigationTarget(
            metadata: TrackCachedMetadata(
                trackId: libraryTrack.trackId,
                title: nil,
                artist: "Artist",
                album: "Album",
                albumArtist: "Album Artist",
                duration: nil,
                year: nil,
                label: nil,
                genre: nil,
                comment: nil
            )
        )
        let builder = TrackListRowStateBuilder()

        let libraryWithoutTarget = builder.build(
            track: libraryTrack,
            snapshot: nil,
            isCurrent: false,
            isPlaying: false,
            isHighlighted: false,
            isFavorite: false,
            settings: .defaultValue,
            collectionNavigationTarget: nil
        )
        let libraryWithTarget = builder.build(
            track: libraryTrack,
            snapshot: nil,
            isCurrent: false,
            isPlaying: false,
            isHighlighted: false,
            isFavorite: false,
            settings: .defaultValue,
            collectionNavigationTarget: target
        )
        let purchased = builder.build(
            track: purchasedTrack,
            snapshot: nil,
            isCurrent: false,
            isPlaying: false,
            isHighlighted: false,
            isFavorite: false,
            settings: .defaultValue,
            collectionNavigationTarget: nil
        )

        XCTAssertTrue(libraryWithoutTarget.availableActions.contains(.renameFile))
        XCTAssertFalse(libraryWithoutTarget.availableActions.contains(.goToArtist))
        XCTAssertTrue(libraryWithTarget.availableActions.contains(.goToArtist))
        XCTAssertTrue(libraryWithTarget.availableActions.contains(.goToAlbum))
        XCTAssertTrue(purchased.availableActions.contains(.copy))
        XCTAssertFalse(purchased.availableActions.contains(.renameFile))
        XCTAssertFalse(purchased.availableActions.contains(.goToArtist))
    }

    /// Rename handler строит request из runtime snapshot, не передавая command обратно в ViewModel.
    func testRenameHandlerBuildsRequestFromReaderAndRuntimeSnapshot() {
        let track = makeTrack(fileName: "Stored.flac")
        let snapshot = makeSnapshot(trackId: track.trackId, title: "Runtime title")
        let reader = DetailReaderSpy(
            trackListId: UUID(),
            tracks: [track],
            snapshots: [track.trackId: snapshot]
        )
        let fileRenamer = DetailFileRenamerSpy()
        let handler = TrackListRenameHandler(
            reader: reader,
            fileRenamer: fileRenamer,
            toastPresenter: DetailToastPresenter()
        )

        handler.renameFile(rowId: track.id, strategy: .artistTitle)

        XCTAssertEqual(fileRenamer.requests.map(\.trackId), [track.trackId])
        XCTAssertEqual(fileRenamer.requests.map(\.rowId), [track.id])
        XCTAssertEqual(fileRenamer.requests.first?.currentFileName, snapshot.fileName)
        XCTAssertEqual(fileRenamer.requests.first?.title, snapshot.title)
    }

    /// Presentation handler передаёт prepared artist и album targets без нового registry lookup.
    func testCollectionNavigationUsesPreparedTargetsWithoutRegistryLookup() {
        let track = makeTrack(fileName: "Navigation.flac")
        let target = TrackCollectionNavigationTarget(
            metadata: TrackCachedMetadata(
                trackId: track.trackId,
                title: nil,
                artist: "Artist",
                album: "Album",
                albumArtist: "Album Artist",
                duration: nil,
                year: nil,
                label: nil,
                genre: nil,
                comment: nil
            )
        )
        let reader = DetailReaderSpy(
            trackListId: UUID(),
            tracks: [track],
            collectionTargets: [track.id: target]
        )
        let navigator = DetailCollectionNavigatorSpy()
        let handler = TrackListPresentationHandler(
            reader: reader,
            presenter: DetailTrackListPresenterSpy(),
            toastPresenter: DetailToastPresenter(),
            commandExecutor: DetailPurchasedITunesPlayerAddingSpy(),
            collectionNavigationHandler: navigator,
            trackShareActionHandler: TrackShareActionHandler(
                preparationService: TrackSharePreparationService(),
                viewControllerProvider: DetailViewControllerProvider(),
                toastPresenter: DetailToastPresenter()
            ),
            favoriteActionHandler: FavoriteTrackActionHandler(
                favoritesService: DetailFavoritesServiceSpy()
            )
        )

        handler.goToArtist(rowId: track.id)
        handler.goToAlbum(rowId: track.id)

        XCTAssertEqual(navigator.artistTargets, [target])
        XCTAssertEqual(navigator.albumTargets, [target])
        XCTAssertEqual(reader.collectionTargetRequestCount, 2)
    }

    /// Недоступная строка треклиста использует только presentation-route и не меняет список.
    func testUnavailableRowRoutesToToastWithoutMutatingTrackList() {
        let track = makeTrack(fileName: "Unavailable.flac")
        let reader = DetailReaderSpy(
            trackListId: UUID(),
            tracks: [track]
        )
        let toastPresenter = DetailToastPresenter()
        let handler = TrackListPresentationHandler(
            reader: reader,
            presenter: DetailTrackListPresenterSpy(),
            toastPresenter: toastPresenter,
            commandExecutor: DetailPurchasedITunesPlayerAddingSpy(),
            collectionNavigationHandler: DetailCollectionNavigatorSpy(),
            trackShareActionHandler: TrackShareActionHandler(
                preparationService: TrackSharePreparationService(),
                viewControllerProvider: DetailViewControllerProvider(),
                toastPresenter: toastPresenter
            ),
            favoriteActionHandler: FavoriteTrackActionHandler(
                favoritesService: DetailFavoritesServiceSpy()
            )
        )

        handler.presentUnavailableTrack(rowId: track.id)

        XCTAssertEqual(
            toastPresenter.events,
            [.trackUnavailable(title: "Stored title")]
        )
        XCTAssertEqual(reader.tracks, [track])
    }

    /// Изменение metadata текущего трека обновляет prepared capabilities и скрывает исчезнувшую цель.
    func testRelevantTrackUpdateRemovesMissingCollectionNavigationTarget() async {
        let trackListId = UUID()
        let track = makeTrack(fileName: "Metadata.flac")
        let metadataLoader = DetailMetadataLoader(
            metadata: [
                track.trackId: TrackCachedMetadata(
                    trackId: track.trackId,
                    title: nil,
                    artist: "Artist",
                    album: "Album",
                    albumArtist: nil,
                    duration: nil,
                    year: nil,
                    label: nil,
                    genre: nil,
                    comment: nil
                )
            ]
        )
        let fixture = makeFixture(
            trackListId: trackListId,
            outcomes: [.success(makeTrackList(id: trackListId, tracks: [track]))],
            metadataLoader: metadataLoader
        )

        fixture.viewModel.loadIfNeeded()
        await yieldToDetailTasks()
        XCTAssertTrue(tryLoadedState(from: fixture.viewModel)?.rows.first?.availableActions.contains(.goToArtist) == true)
        await metadataLoader.replaceMetadata([:])
        fixture.events.trackDidUpdateSubject.send(
            TrackUpdateEvent(
                trackId: track.trackId,
                reason: .metadataUpdated,
                changedFields: [.artist, .album],
                snapshot: makeSnapshot(trackId: track.trackId, title: "Updated")
            )
        )
        await yieldToDetailTasks()

        XCTAssertFalse(tryLoadedState(from: fixture.viewModel)?.rows.first?.availableActions.contains(.goToArtist) == true)
        XCTAssertFalse(tryLoadedState(from: fixture.viewModel)?.rows.first?.availableActions.contains(.goToAlbum) == true)
    }

    // MARK: - Helpers

    /// Собирает ViewModel только с узкими test doubles detail-flow.
    private func makeFixture(
        trackListId: UUID = UUID(),
        outcomes: [Result<TrackList, Error>],
        settings: DetailSettingsManager? = nil,
        playback: DetailPlaybackProvider? = nil,
        favorites: DetailFavoritesProvider? = nil,
        snapshotBuilder: ControlledRuntimeSnapshotBuilder? = nil,
        summaryProvider: DetailSummaryProvider? = nil,
        metadataLoader: DetailMetadataLoader? = nil
    ) -> DetailFixture {
        let loader = DetailLoader(outcomes: outcomes)
        let events = DetailEventProvider()
        let toastPresenter = DetailToastPresenter()
        let settings = settings ?? DetailSettingsManager()
        let playback = playback ?? DetailPlaybackProvider()
        let favorites = favorites ?? DetailFavoritesProvider(storedIds: [])
        let snapshotBuilder = snapshotBuilder ?? ControlledRuntimeSnapshotBuilder()
        let summaryProvider = summaryProvider ?? DetailSummaryProvider()
        let metadataLoader = metadataLoader ?? DetailMetadataLoader()
        let viewModel = TrackListViewModel(
            trackListId: trackListId,
            detailLoader: loader,
            toastPresenter: toastPresenter,
            eventProvider: events,
            settingsManager: settings,
            playbackStateProvider: playback,
            favoriteTrackIdsProvider: favorites,
            runtimeSnapshotProvider: DetailRuntimeSnapshotProvider(),
            runtimeSnapshotBuilder: snapshotBuilder,
            summaryProvider: summaryProvider,
            collectionMetadataLoader: metadataLoader
        )

        return DetailFixture(
            viewModel: viewModel,
            loader: loader,
            events: events,
            toastPresenter: toastPresenter
        )
    }

    /// Собирает полный detail ActionHandler с inert doubles, чтобы проверить только typed lifecycle ingress.
    private func makeFlowActionHandler(
        for viewModel: TrackListViewModel
    ) -> TrackListFlowActionHandler {
        let toastPresenter = DetailToastPresenter()

        return TrackListFlowActionHandler(
            reader: viewModel,
            lifecycle: viewModel,
            playbackStateProvider: DetailPlaybackProvider(),
            playbackController: DetailPlaybackControllerSpy(),
            trackListManager: DetailTrackListManagerSpy(),
            commandExecutor: DetailTrackListCommandSpy(result: .failure(DetailTestError.failed)),
            fileRenamer: DetailFileRenamerSpy(),
            presenter: DetailTrackListPresenterSpy(),
            exportRequestHandler: DetailExportRequestHandlerSpy(),
            toastPresenter: toastPresenter,
            appCommandExecutor: DetailPurchasedITunesPlayerAddingSpy(),
            collectionNavigationHandler: DetailCollectionNavigatorSpy(),
            trackShareActionHandler: TrackShareActionHandler(
                preparationService: TrackSharePreparationService(),
                viewControllerProvider: DetailViewControllerProvider(),
                toastPresenter: toastPresenter
            ),
            favoriteTrackActionHandler: FavoriteTrackActionHandler(
                favoritesService: DetailFavoritesServiceSpy()
            )
        )
    }

    /// Возвращает loaded state или фиксирует ошибку проверяемого контракта.
    private func tryLoadedState(
        from viewModel: TrackListViewModel,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> TrackListScreenState? {
        guard case .loaded(let state) = viewModel.content else {
            XCTFail("Ожидался loaded ScreenState", file: file, line: line)
            return nil
        }

        return state
    }

    /// Даёт MainActor и controlled async задачам пройти без time-based ожиданий.
    private func yieldToDetailTasks() async {
        for _ in 0..<12 {
            await Task.yield()
        }
    }

    /// Создаёт тестовую строку с независимыми row и physical track identity.
    private func makeTrack(
        trackId: UUID = UUID(),
        fileName: String = "Track.flac",
        source: TrackSource = .library,
        assetURL: URL? = nil
    ) -> Track {
        Track(
            trackId: trackId,
            title: "Stored title",
            artist: "Stored artist",
            duration: 120,
            fileName: fileName,
            isAvailable: true,
            source: source,
            assetURL: assetURL
        )
    }

    /// Создаёт полный detail snapshot, аналогичный ответу узкого loader-а.
    private func makeTrackList(id: UUID, tracks: [Track]) -> TrackList {
        TrackList(
            id: id,
            name: "Detail",
            createdAt: Date(timeIntervalSince1970: 0),
            kind: .regular,
            tracks: tracks
        )
    }

    /// Создаёт короткий runtime snapshot с различимыми данными для race-проверок.
    private func makeSnapshot(trackId: UUID, title: String) -> TrackRuntimeSnapshot {
        TrackRuntimeSnapshot(
            trackId: trackId,
            fileName: "\(title).flac",
            isAvailable: true,
            technicalMetadata: TrackTechnicalMetadata(
                fileSizeBytes: nil,
                fileFormat: "FLAC",
                bitrateBitsPerSecond: nil
            ),
            title: title,
            artist: "Artist",
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
            duration: 120,
            artworkData: nil,
            artworkSourceIdentifier: nil,
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}

/// Группирует объекты fixture, которые должны жить столько же, сколько ViewModel в тесте.
@MainActor
private struct DetailFixture {
    let viewModel: TrackListViewModel
    let loader: DetailLoader
    let events: DetailEventProvider
    let toastPresenter: DetailToastPresenter
}

/// Возвращает заранее заданные detail snapshot-ы и фиксирует число обращений.
@MainActor
private final class DetailLoader: TrackListDetailLoading {
    private var outcomes: [Result<TrackList, Error>]
    private(set) var loadCallCount = 0

    init(outcomes: [Result<TrackList, Error>]) {
        self.outcomes = outcomes
    }

    func loadTrackList(id: UUID) throws -> TrackList {
        loadCallCount += 1
        guard outcomes.isEmpty == false else {
            throw DetailTestError.failed
        }

        return try outcomes.removeFirst().get()
    }
}

/// Публикует только локально управляемые invalidation-сигналы detail-flow.
private final class DetailEventProvider: TrackListEventProviding {
    let trackDidUpdateSubject = PassthroughSubject<TrackUpdateEvent, Never>()
    let appSettingsDidChangeSubject = PassthroughSubject<Void, Never>()
    let trackListTracksSubject = PassthroughSubject<UUID, Never>()
    let libraryDataDidChangeSubject = PassthroughSubject<Void, Never>()
    let trackListsDidChangeSubject = PassthroughSubject<Void, Never>()

    var trackDidUpdate: AnyPublisher<TrackUpdateEvent, Never> {
        trackDidUpdateSubject.eraseToAnyPublisher()
    }

    var appSettingsDidChange: AnyPublisher<Void, Never> {
        appSettingsDidChangeSubject.eraseToAnyPublisher()
    }

    var trackListTracksDidChange: AnyPublisher<UUID, Never> {
        trackListTracksSubject.eraseToAnyPublisher()
    }

    var libraryDataDidChange: AnyPublisher<Void, Never> {
        libraryDataDidChangeSubject.eraseToAnyPublisher()
    }

    var trackListsDidChange: AnyPublisher<Void, Never> {
        trackListsDidChangeSubject.eraseToAnyPublisher()
    }
}

/// Хранит settings snapshot и воспроизводит published-изменение без persistent storage.
@MainActor
private final class DetailSettingsManager: SettingsManaging {
    @Published private var currentSettings = AppSettings.defaultValue

    var settings: AppSettings { currentSettings }
    var settingsPublisher: Published<AppSettings>.Publisher { $currentSettings }

    func setTagReadingEnabled(_ value: Bool) {
        currentSettings.visible.metadata.isTagReadingEnabled = value
    }

    func setTrackListMembershipVisible(_: Bool) {}
    func setFileFormatVisible(_: Bool) {}
    func setPurchasedITunesSourceVisible(_: Bool) {}
    func setMiniPlayerExpanded(_: Bool) {}
    func setLibraryRootDisplayMode(_: LibraryRootDisplayMode) throws {}
    func setLibraryTrackSortMode(_: LibraryTrackSortMode) throws {}
    func setTrackListsSortMode(_: TrackListsSortMode?) throws {}

    func applyPersistedTrackListsSortMode(_: TrackListsSortMode?) {
        // Этот test double не хранит состояние сортировки треклистов.
    }
}

/// Публикует immutable playback snapshot, не раскрывая PlayerViewModel.
@MainActor
private final class DetailPlaybackProvider: PlaybackStateProviding {
    private let subject = CurrentValueSubject<PlaybackStateSnapshot, Never>(
        PlaybackStateSnapshot(
            currentDisplayableId: nil,
            currentTrackId: nil,
            currentContext: nil,
            currentContextSource: nil,
            isPlaying: false
        )
    )

    var playbackState: PlaybackStateSnapshot { subject.value }
    var currentDisplayableId: UUID? { playbackState.currentDisplayableId }
    var currentTrackId: UUID? { playbackState.currentTrackId }
    var currentContext: PlaybackContext? { playbackState.currentContext }
    var currentContextSource: PlaybackContextSource? { playbackState.currentContextSource }
    var isPlaying: Bool { playbackState.isPlaying }
    var playbackStatePublisher: AnyPublisher<PlaybackStateSnapshot, Never> {
        subject.eraseToAnyPublisher()
    }

    /// Передаёт уже подтверждённый publisher snapshot в detail ViewModel.
    func emit(_ state: PlaybackStateSnapshot) {
        subject.send(state)
    }
}

/// Не выполняет playback-команды, потому что lifecycle-тесты проверяют только initial loading.
@MainActor
private final class DetailPlaybackControllerSpy: TrackPlaybackControlling {
    func togglePlayPause() {}

    func play(
        track: any TrackDisplayable,
        context: [any TrackDisplayable],
        source: PlaybackContextSource
    ) {}
}

/// Воспроизводит регрессию: publisher уже содержит новое значение, property намеренно остаётся старым.
@MainActor
private final class DetailFavoritesProvider: FavoriteTrackIdsProviding {
    private let subject = PassthroughSubject<Set<UUID>, Never>()
    private let storedIds: Set<UUID>

    init(storedIds: Set<UUID>) {
        self.storedIds = storedIds
    }

    var favoriteTrackIds: Set<UUID> { storedIds }
    var favoriteTrackIdsPublisher: AnyPublisher<Set<UUID>, Never> {
        subject.eraseToAnyPublisher()
    }

    /// Отправляет новый confirmed snapshot, сохраняя property для проверки stale-provider path.
    func emitWithoutChangingStoredProperty(_ ids: Set<UUID>) {
        subject.send(ids)
    }
}

/// Предоставляет только уже сохранённые snapshot-ы и никогда не инициирует файловое чтение.
@MainActor
private final class DetailRuntimeSnapshotProvider: TrackRuntimeSnapshotProviding {
    private let snapshots: [UUID: TrackRuntimeSnapshot]

    init(snapshots: [UUID: TrackRuntimeSnapshot] = [:]) {
        self.snapshots = snapshots
    }

    func snapshot(forTrackId trackId: UUID) -> TrackRuntimeSnapshot? {
        snapshots[trackId]
    }
}

/// Управляемый async builder удерживает completion до явного выпуска тестом.
private actor ControlledRuntimeSnapshotBuilder: TrackRuntimeSnapshotBuilding {
    private var requestCounts: [UUID: Int] = [:]
    private var continuations: [UUID: [CheckedContinuation<TrackRuntimeSnapshot?, Never>]] = [:]

    func buildSnapshot(forTrackId trackId: UUID) async throws -> TrackRuntimeSnapshot? {
        requestCounts[trackId, default: 0] += 1

        return await withCheckedContinuation { continuation in
            continuations[trackId, default: []].append(continuation)
        }
    }

    /// Возвращает количество реально начатых тяжёлых build-операций конкретного physical track ID.
    func requestCount(for trackId: UUID) -> Int {
        requestCounts[trackId, default: 0]
    }

    /// Завершает следующую ожидающую операцию в FIFO-порядке для проверки stale результатов.
    func completeNext(
        for trackId: UUID,
        with snapshot: TrackRuntimeSnapshot?
    ) {
        guard continuations[trackId]?.isEmpty == false else {
            return
        }

        let continuation = continuations[trackId]!.removeFirst()
        continuation.resume(returning: snapshot)
    }
}

/// Actor возвращает последовательность summary результатов без SQLite provider-а.
private actor DetailSummaryProvider: TrackCollectionSummaryProviding {
    private var outcomes: [Result<TrackCollectionSummary, Error>]

    init(outcomes: [Result<TrackCollectionSummary, Error>] = []) {
        self.outcomes = outcomes
    }

    func summaryForFolder(folderId: UUID) async throws -> TrackCollectionSummary {
        throw DetailTestError.failed
    }

    func summaryForTrackList(trackListId: UUID) async throws -> TrackCollectionSummary {
        guard outcomes.isEmpty == false else {
            return TrackCollectionSummary(
                trackCount: 0,
                totalDuration: nil,
                totalFileSize: nil,
                unknownDurationCount: 0,
                unknownFileSizeCount: 0
            )
        }

        return try outcomes.removeFirst().get()
    }
}

/// Возвращает подготовленные metadata только для затребованных строк.
private actor DetailMetadataLoader: TrackCollectionMetadataLoading {
    private var metadata: [UUID: TrackCachedMetadata]

    init(metadata: [UUID: TrackCachedMetadata] = [:]) {
        self.metadata = metadata
    }

    func cachedMetadata(forTrackIds trackIds: [UUID]) async -> [UUID: TrackCachedMetadata] {
        metadata.filter { trackIds.contains($0.key) }
    }

    /// Меняет ответ fake до следующего controlled invalidation.
    func replaceMetadata(_ metadata: [UUID: TrackCachedMetadata]) {
        self.metadata = metadata
    }
}

/// Фиксирует semantic ошибки и toast-события без ToastManager.
@MainActor
private final class DetailToastPresenter: ToastPresenting {
    private(set) var errors: [AppError] = []
    private(set) var events: [ToastEvent] = []

    func handle(_ error: AppError) {
        errors.append(error)
    }

    func handle(_ event: ToastEvent, duration: TimeInterval) {
        events.append(event)
    }
}

/// Предоставляет read-only snapshot для command handler-ов.
@MainActor
private final class DetailReaderSpy: TrackListReading {
    let trackListId: UUID
    let name = "Detail"
    let tracks: [Track]
    private let snapshots: [UUID: TrackRuntimeSnapshot]
    private let collectionTargets: [UUID: TrackCollectionNavigationTarget]
    private(set) var collectionTargetRequestCount = 0

    init(
        trackListId: UUID,
        tracks: [Track],
        snapshots: [UUID: TrackRuntimeSnapshot] = [:],
        collectionTargets: [UUID: TrackCollectionNavigationTarget] = [:]
    ) {
        self.trackListId = trackListId
        self.tracks = tracks
        self.snapshots = snapshots
        self.collectionTargets = collectionTargets
    }

    func runtimeSnapshot(forTrackId trackId: UUID) -> TrackRuntimeSnapshot? {
        snapshots[trackId]
    }

    func collectionNavigationTarget(forRowId rowId: UUID) -> TrackCollectionNavigationTarget? {
        collectionTargetRequestCount += 1
        return collectionTargets[rowId]
    }
}

/// Фиксирует manager persistence порядка без постоянного хранилища.
@MainActor
private final class DetailTrackListManagerSpy: TrackListManaging {
    private let shouldSave: Bool
    private(set) var savedTrackIds: [[UUID]] = []
    private(set) var savedTrackListIds: [UUID] = []

    init(shouldSave: Bool = true) {
        self.shouldSave = shouldSave
    }

    func loadTracks(for id: UUID) throws -> [Track] { [] }

    func saveTracks(_ tracks: [Track], for id: UUID) -> Bool {
        savedTrackIds.append(tracks.map(\.id))
        savedTrackListIds.append(id)
        return shouldSave
    }
}

/// Фиксирует domain delete command и не обращается к AppCommandExecutor.
@MainActor
private final class DetailTrackListCommandSpy: TrackListCommandExecuting {
    struct Request: Equatable {
        let listItemId: UUID
        let trackListId: UUID
    }

    private let result: Result<Track, Error>
    private(set) var requests: [Request] = []

    init(result: Result<Track, Error>) {
        self.result = result
    }

    func removeTrackFromTrackList(
        listItemId: UUID,
        trackListId: UUID
    ) async throws -> TrackRemovedFromTrackListSuccess {
        requests.append(Request(listItemId: listItemId, trackListId: trackListId))
        return TrackRemovedFromTrackListSuccess(
            removedTrack: try result.get(),
            trackListId: trackListId
        )
    }
}

/// Фиксирует подготовленный request rename-flow без SheetManager и файловой операции.
@MainActor
private final class DetailFileRenamerSpy: TrackFileRenaming {
    private(set) var requests: [TrackFileRenameRequest] = []

    func handle(_ request: TrackFileRenameRequest) {
        requests.append(request)
    }
}

/// Фиксирует готовые collection targets, не читая TrackRegistry.
@MainActor
private final class DetailCollectionNavigatorSpy: TrackCollectionNavigating {
    private(set) var artistTargets: [TrackCollectionNavigationTarget] = []
    private(set) var albumTargets: [TrackCollectionNavigationTarget] = []

    func openArtist(target: TrackCollectionNavigationTarget) {
        artistTargets.append(target)
    }

    func openAlbum(target: TrackCollectionNavigationTarget) {
        albumTargets.append(target)
    }
}

/// Реализует остальные presentation-команды, не затрагиваемые проверкой collection route.
@MainActor
private final class DetailTrackListPresenterSpy: TrackListPresenting {
    func presentAddTrack(to trackListId: UUID) {}
    func presentRenameTrackList(trackListId: UUID, currentName: String) {}
    func presentTrackDetail(_ track: Track) {}
    func presentCopyPurchasedITunesTrack(_ track: PurchasedITunesPlayableTrack) {}
    func presentTrackTagsEditor(_ track: Track) {}
    func showInLibrary(_ track: Track) {}
    func moveToFolder(_ track: Track) {}
}

/// Запрещает тесту запускать не относящуюся к navigation iTunes-команду.
private final class DetailPurchasedITunesPlayerAddingSpy: PurchasedITunesTrackPlayerAdding {
    func addPurchasedITunesTrackToPlayer(
        _ track: PurchasedITunesPlayableTrack
    ) async throws -> PurchasedITunesTrackAddedToPlayerSuccess {
        throw DetailTestError.failed
    }
}

/// Возвращает отсутствие UIKit presenter-а, потому что share-flow в этой проверке не запускается.
@MainActor
private final class DetailViewControllerProvider: ViewControllerProviding {
    func topViewController() -> UIViewController? { nil }
}

/// Реализует неиспользуемые Favorites-команды без обращения к persistent storage.
@MainActor
private final class DetailFavoritesServiceSpy: FavoritesServicing {
    func loadFavoriteTrackIds() throws -> Set<UUID> { [] }
    func isFavorite(trackId: UUID) throws -> Bool { false }
    func add(_ track: FavoriteTrackInput) throws -> FavoritesMutationResult { .added }
    func remove(trackId: UUID) throws -> FavoritesMutationResult { .removed }
    func toggle(_ track: FavoriteTrackInput) throws -> FavoritesMutationResult { .unchanged(isFavorite: false) }
}

/// Игнорирует export request, потому что lifecycle-тесты не должны запускать глобальный Export-feature.
@MainActor
private final class DetailExportRequestHandlerSpy: ExportRequestHandling {
    func startExport(_ request: ExportRequest) {}
}

/// Локальная управляемая ошибка test doubles.
private enum DetailTestError: Error {
    case failed
}
