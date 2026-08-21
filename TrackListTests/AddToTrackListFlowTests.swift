//
//  AddToTrackListFlowTests.swift
//  TrackList
//
//  Focused-проверки flow добавления треков в треклист.
//
//  Created by Pavel Fomin on 03.08.2026.
//

import Foundation
import XCTest
@testable import TrackList

/// Проверяет mapping, ViewModel и ActionHandler Add To TrackList через явные feature-зависимости.
@MainActor
final class AddToTrackListFlowTests: XCTestCase {

    func testLibraryTrackMapsToLibraryRequest() {
        let track = makeLibraryTrack(name: "Library.mp3")

        let request = AddToTrackListRequestMapper().map(
            AddToTrackListSheetData(track: track)
        )

        XCTAssertEqual(request.trackIds, [track.trackId])
        XCTAssertNil(request.excludedTrackListId)
        guard case .libraryTrack(let trackId) = request.source else {
            return XCTFail("Одиночный Library track должен использовать library request")
        }
        XCTAssertEqual(trackId, track.trackId)
    }

    func testPurchasedITunesTrackKeepsRuntimeSourceContext() {
        let track = makePurchasedITunesTrack()

        let request = AddToTrackListRequestMapper().map(
            AddToTrackListSheetData(track: track)
        )

        guard case .purchasedITunes(let tracks) = request.source else {
            return XCTFail("Purchased iTunes должен сохранить runtime-модель в request")
        }
        XCTAssertEqual(tracks.map(\.trackId), [track.trackId])
        XCTAssertEqual(request.trackIds, [track.trackId])
    }

    func testLibraryBatchPreservesTrackIDsAndOrder() {
        let first = makeLibraryTrack(name: "First.mp3")
        let second = makeLibraryTrack(name: "Second.mp3")

        let request = AddToTrackListRequestMapper().map(
            AddToTrackListSheetData(libraryBatchTracks: [second, first])
        )

        XCTAssertEqual(request.trackIds, [second.trackId, first.trackId])
        guard case .libraryBatch(let tracks) = request.source else {
            return XCTFail("Batch Library должен использовать libraryBatch request")
        }
        XCTAssertEqual(tracks.map(\.trackId), [second.trackId, first.trackId])
    }

    func testSourceTrackListIDIsPreservedAndExcludedFromDestination() {
        let track = makeLibraryTrack(name: "Source.mp3")
        let sourceTrackListId = UUID()
        let destination = makeTrackListMeta(name: "Destination")
        let request = AddToTrackListRequestMapper().map(
            AddToTrackListSheetData(
                track: track,
                sourceTrackListId: sourceTrackListId
            )
        )
        let (viewModel, _, _, _) = makeViewModel(
            request: request,
            trackLists: [
                makeTrackListMeta(id: sourceTrackListId, name: "Source"),
                destination
            ]
        )

        XCTAssertEqual(request.excludedTrackListId, sourceTrackListId)
        XCTAssertFalse(viewModel.state.items.first { $0.id == sourceTrackListId }?.isAvailable ?? true)
        XCTAssertTrue(viewModel.state.items.first { $0.id == destination.id }?.isAvailable ?? false)
    }

    func testInitialStateContainsAvailableTrackLists() {
        let first = makeTrackListMeta(name: "First")
        let second = makeTrackListMeta(name: "Second")
        let (viewModel, _, _, _) = makeViewModel(trackLists: [first, second])

        XCTAssertEqual(Set(viewModel.state.items.map(\.id)), Set([first.id, second.id]))
        XCTAssertNil(viewModel.state.selectedTrackListId)
        XCTAssertFalse(viewModel.state.canSubmit)
    }

    func testSelectionUpdatesStateAndEnablesSubmit() {
        let destination = makeTrackListMeta(name: "Destination")
        let (viewModel, _, _, _) = makeViewModel(trackLists: [destination])

        viewModel.handle(.trackListSelected(destination.id))

        XCTAssertEqual(viewModel.state.selectedTrackListId, destination.id)
        XCTAssertTrue(viewModel.state.items.first?.isSelected ?? false)
        XCTAssertTrue(viewModel.state.canSubmit)
    }

    func testSubmitWithoutSelectionDoesNotInvokeCommand() async {
        let destination = makeTrackListMeta(name: "Destination")
        let (viewModel, _, executor, _) = makeViewModel(trackLists: [destination])

        viewModel.handle(.submit)
        await Task.yield()

        let requests = executor.libraryTrackRequests()
        XCTAssertTrue(requests.isEmpty)
    }

    func testRepeatedSubmitIsIgnoredWhileCommandIsScheduled() async {
        let destination = makeTrackListMeta(name: "Destination")
        let (viewModel, _, executor, _) = makeViewModel(trackLists: [destination])

        viewModel.handle(.trackListSelected(destination.id))
        viewModel.handle(.submit)
        viewModel.handle(.submit)

        XCTAssertTrue(viewModel.state.isSubmitting)
        await completeScheduledTask()

        let requests = executor.libraryTrackRequests()
        XCTAssertEqual(requests.count, 1)
    }

    func testCancelClosesFlowThroughExplicitRouter() {
        let (viewModel, _, _, router) = makeViewModel()

        viewModel.handle(.cancel)

        XCTAssertEqual(router.closeCount, 1)
    }

    func testLibraryTrackSubmitInvokesLibraryCommand() async {
        let destination = makeTrackListMeta(name: "Destination")
        let track = makeLibraryTrack(name: "Library.mp3")
        let request = AddToTrackListRequest(
            trackIds: [track.trackId],
            source: .libraryTrack(trackId: track.trackId),
            excludedTrackListId: nil
        )
        let (_, _, executor, router) = makeViewModel(
            request: request,
            trackLists: [destination]
        )
        let handler = makeActionHandler(
            trackListsService: AddToTrackListTrackListsSpy(),
            executor: executor,
            toast: AddToTrackListToastSpy(),
            router: router
        )

        _ = await handler.submit(request: request, destination: destination)

        let requests = executor.libraryTrackRequests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.0, track.trackId)
        XCTAssertEqual(requests.first?.1, destination.id)
        XCTAssertEqual(router.closeCount, 1)
    }

    func testPurchasedITunesSubmitInvokesPurchasedCommand() async {
        let destination = makeTrackListMeta(name: "Destination")
        let track = makePurchasedITunesTrack()
        let request = AddToTrackListRequest(
            trackIds: [track.trackId],
            source: .purchasedITunes(tracks: [track]),
            excludedTrackListId: nil
        )
        let executor = AddToTrackListExecutorSpy()
        let router = AddToTrackListRouterSpy()
        let handler = makeActionHandler(
            trackListsService: AddToTrackListTrackListsSpy(),
            executor: executor,
            toast: AddToTrackListToastSpy(),
            router: router
        )

        _ = await handler.submit(request: request, destination: destination)

        let trackIDs = executor.purchasedTrackIDs()
        XCTAssertEqual(trackIDs, [track.trackId])
        XCTAssertEqual(router.closeCount, 1)
    }

    func testLibraryBatchSubmitPreservesOrderAndUsesTrackListsService() async {
        let destination = makeTrackListMeta(name: "Destination")
        let first = makeLibraryTrack(name: "First.mp3")
        let second = makeLibraryTrack(name: "Second.mp3")
        let request = AddToTrackListRequest(
            trackIds: [second.trackId, first.trackId],
            source: .libraryBatch(tracks: [second, first]),
            excludedTrackListId: nil
        )
        let service = AddToTrackListTrackListsSpy()
        let router = AddToTrackListRouterSpy()
        let handler = makeActionHandler(
            trackListsService: service,
            executor: AddToTrackListExecutorSpy(),
            toast: AddToTrackListToastSpy(),
            router: router
        )

        _ = await handler.submit(request: request, destination: destination)

        XCTAssertEqual(service.libraryBatchRequests.count, 1)
        XCTAssertEqual(service.libraryBatchRequests.first?.destinationID, destination.id)
        XCTAssertEqual(
            service.libraryBatchRequests.first?.trackIDs,
            [second.trackId, first.trackId]
        )
        XCTAssertEqual(router.closeCount, 1)
    }

    func testTrackListSourceUsesIDBasedBatchCommand() async {
        let destination = makeTrackListMeta(name: "Destination")
        let trackIds = [UUID(), UUID()]
        let request = AddToTrackListRequest(
            trackIds: trackIds,
            source: .trackList(trackIds: trackIds),
            excludedTrackListId: UUID()
        )
        let executor = AddToTrackListExecutorSpy()
        let router = AddToTrackListRouterSpy()
        let handler = makeActionHandler(
            trackListsService: AddToTrackListTrackListsSpy(),
            executor: executor,
            toast: AddToTrackListToastSpy(),
            router: router
        )

        _ = await handler.submit(request: request, destination: destination)

        let requests = executor.trackListRequests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.0, trackIds)
        XCTAssertEqual(requests.first?.1, destination.id)
        XCTAssertEqual(router.closeCount, 1)
    }

    func testSuccessShowsToast() async {
        let destination = makeTrackListMeta(name: "Destination")
        let trackIds = [UUID(), UUID()]
        let request = AddToTrackListRequest(
            trackIds: trackIds,
            source: .trackList(trackIds: trackIds),
            excludedTrackListId: nil
        )
        let toast = AddToTrackListToastSpy()
        let handler = makeActionHandler(
            trackListsService: AddToTrackListTrackListsSpy(),
            executor: AddToTrackListExecutorSpy(),
            toast: toast,
            router: AddToTrackListRouterSpy()
        )

        _ = await handler.submit(request: request, destination: destination)

        XCTAssertEqual(
            toast.events,
            [.tracksAddedToTrackList(count: trackIds.count, name: destination.name)]
        )
    }

    func testFailureShowsCurrentMessageAndKeepsFlowOpen() async {
        let destination = makeTrackListMeta(name: "Destination")
        let trackId = UUID()
        let request = AddToTrackListRequest(
            trackIds: [trackId],
            source: .libraryTrack(trackId: trackId),
            excludedTrackListId: nil
        )
        let executor = AddToTrackListExecutorSpy()
        let toast = AddToTrackListToastSpy()
        let router = AddToTrackListRouterSpy()
        let handler = makeActionHandler(
            trackListsService: AddToTrackListTrackListsSpy(),
            executor: executor,
            toast: toast,
            router: router
        )
        executor.setError(.trackListSaveFailed)

        let result = await handler.submit(request: request, destination: destination)

        XCTAssertEqual(result, .failure)
        XCTAssertEqual(router.closeCount, 0)
        guard case .trackListSaveFailed? = toast.errors.first else {
            return XCTFail("Должно быть показано текущее сообщение ошибки добавления")
        }
    }

    func testFailureKeepsFlowOpenAndAllowsRetry() async {
        let destination = makeTrackListMeta(name: "Destination")
        let (viewModel, _, executor, router) = makeViewModel(trackLists: [destination])

        executor.setError(.trackListSaveFailed)
        viewModel.handle(.trackListSelected(destination.id))
        viewModel.handle(.submit)
        await completeScheduledTask()

        XCTAssertFalse(viewModel.state.isSubmitting)
        XCTAssertTrue(viewModel.state.canSubmit)
        XCTAssertEqual(router.closeCount, 0)

        executor.setError(nil)
        let closeExpectation = expectation(
            description: "Успешная повторная попытка закрывает route"
        )
        router.onDismiss = {
            closeExpectation.fulfill()
        }
        viewModel.handle(.submit)
        await fulfillment(of: [closeExpectation], timeout: 1)

        let attemptCount = executor.libraryTrackAttemptCount()
        XCTAssertEqual(attemptCount, 2)
        let requests = executor.libraryTrackRequests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(router.closeCount, 1)
    }

    private func makeViewModel(
        request: AddToTrackListRequest? = nil,
        trackLists: [TrackListMeta]? = nil
    ) -> (
        AddToTrackListViewModel,
        AddToTrackListTrackListsSpy,
        AddToTrackListExecutorSpy,
        AddToTrackListRouterSpy
    ) {
        let service = AddToTrackListTrackListsSpy()
        let executor = AddToTrackListExecutorSpy()
        let toast = AddToTrackListToastSpy()
        let router = AddToTrackListRouterSpy()
        let actionHandler = makeActionHandler(
            trackListsService: service,
            executor: executor,
            toast: toast,
            router: router
        )
        let resolvedRequest = request ?? AddToTrackListRequest(
            trackIds: [UUID()],
            source: .libraryTrack(trackId: UUID()),
            excludedTrackListId: nil
        )
        let resolvedTrackLists = trackLists ?? [
            makeTrackListMeta(name: "Destination")
        ]
        let viewModel = AddToTrackListViewModel(
            request: resolvedRequest,
            trackListsResult: .success(resolvedTrackLists),
            stateBuilder: AddToTrackListStateBuilder(),
            actionHandler: actionHandler,
            toastPresenter: toast
        )

        return (viewModel, service, executor, router)
    }

    private func makeActionHandler(
        trackListsService: AddToTrackListTrackListsSpy,
        executor: AddToTrackListExecutorSpy,
        toast: AddToTrackListToastSpy,
        router: AddToTrackListRouterSpy
    ) -> AddToTrackListActionHandler {
        AddToTrackListActionHandler(
            trackListsService: trackListsService,
            commandExecutor: executor,
            toastPresenter: toast,
            router: router
        )
    }

    private func makeLibraryTrack(name: String) -> LibraryTrack {
        LibraryTrack(
            id: UUID(),
            fileURL: URL(fileURLWithPath: "/tmp/\(name)"),
            title: name,
            artist: "Artist",
            duration: 180,
            addedDate: Date()
        )
    }

    private func makePurchasedITunesTrack() -> PurchasedITunesPlayableTrack {
        PurchasedITunesPlayableTrack(
            track: PurchasedITunesTrack(
                id: UInt64.random(in: 1...UInt64.max),
                title: "Purchased",
                artist: "Artist",
                album: "Album",
                year: nil,
                genre: nil,
                dateAdded: Date(),
                artworkData: nil,
                duration: 180,
                assetURL: URL(string: "ipod-library://item/purchased.m4a")!
            )
        )
    }

    private func makeTrackListMeta(
        id: UUID = UUID(),
        name: String
    ) -> TrackListMeta {
        TrackListMeta(
            id: id,
            name: name,
            createdAt: Date(),
            kind: .regular
        )
    }

    private func completeScheduledTask() async {
        try? await Task.sleep(nanoseconds: 100_000_000)
        await Task.yield()
        await Task.yield()
        await Task.yield()
    }
}

/// Небольшой fake зависимости destination-треклистов для focused-тестов.
@MainActor
private final class AddToTrackListTrackListsSpy: AddToTrackListTrackListsManaging {
    var libraryBatchRequests: [(destinationID: UUID, trackIDs: [UUID])] = []
    var libraryBatchError: Error?

    func loadTrackListMetas() throws -> [TrackListMeta] {
        []
    }

    func addTracks(_ libraryTracks: [LibraryTrack], to trackListId: UUID) throws -> TrackList {
        if let libraryBatchError {
            throw libraryBatchError
        }

        libraryBatchRequests.append(
            (destinationID: trackListId, trackIDs: libraryTracks.map(\.trackId))
        )
        return TrackList(
            id: trackListId,
            name: "Append target",
            createdAt: Date(),
            kind: .regular,
            tracks: []
        )
    }
}

/// MainActor-double существующего command executor для всех асинхронных веток flow.
@MainActor
private final class AddToTrackListExecutorSpy: AddToTrackListExecuting {
    private var error: AppError?
    private var libraryTrackAttemptCountValue = 0
    private var libraryRequests: [(UUID, UUID)] = []
    private var trackListBatchRequests: [([UUID], UUID)] = []
    private var purchasedRequests: [[UUID]] = []

    func setError(_ error: AppError?) {
        self.error = error
    }

    func libraryTrackRequests() -> [(UUID, UUID)] {
        libraryRequests
    }

    func libraryTrackAttemptCount() -> Int {
        libraryTrackAttemptCountValue
    }

    func trackListRequests() -> [([UUID], UUID)] {
        trackListBatchRequests
    }

    func purchasedTrackIDs() -> [UUID] {
        purchasedRequests.flatMap { $0 }
    }

    func addTrackToTrackList(
        trackId: UUID,
        trackListId: UUID
    ) async throws -> TrackAddedToTrackListSuccess {
        libraryTrackAttemptCountValue += 1

        if let error {
            throw error
        }

        libraryRequests.append((trackId, trackListId))
        return TrackAddedToTrackListSuccess(
            addedTrack: makeTrack(trackId: trackId),
            trackListId: trackListId,
            trackListName: "Destination"
        )
    }

    func addTracksToTrackList(
        trackIds: [UUID],
        trackListId: UUID
    ) async throws -> TracksAddedToTrackListSuccess {
        if let error {
            throw error
        }

        trackListBatchRequests.append((trackIds, trackListId))
        return TracksAddedToTrackListSuccess(
            addedTrackIds: trackIds,
            trackListId: trackListId,
            trackListName: "Destination"
        )
    }

    func addPurchasedITunesTracksToTrackList(
        _ tracks: [PurchasedITunesPlayableTrack],
        trackListId: UUID
    ) async throws -> PurchasedITunesTracksAddedToTrackListSuccess {
        if let error {
            throw error
        }

        purchasedRequests.append(tracks.map(\.trackId))
        return PurchasedITunesTracksAddedToTrackListSuccess(
            addedTracks: tracks.map(Track.init(purchasedITunesTrack:)),
            trackListId: trackListId,
            trackListName: "Destination"
        )
    }

    private func makeTrack(trackId: UUID) -> Track {
        Track(
            trackId: trackId,
            title: "Track",
            artist: "Artist",
            duration: 180,
            fileName: "Track.mp3",
            isAvailable: true
        )
    }
}

/// Запоминает сообщения, переданные flow в presentation-слой.
@MainActor
private final class AddToTrackListToastSpy: ToastPresenting {
    var events: [ToastEvent] = []
    var errors: [AppError] = []

    func handle(_ event: ToastEvent, duration: TimeInterval) {
        events.append(event)
    }

    func handle(_ error: AppError) {
        errors.append(error)
    }
}

/// Проверяет typed-маршрутизацию Add To TrackList без зависимости от SheetManager.
@MainActor
private final class AddToTrackListRouterSpy: AddToTrackListRouting {
    var closeCount = 0
    /// Сигнализирует тесту о действительном завершении асинхронного route, а не о произвольной задержке Task.
    var onDismiss: (() -> Void)?

    func dismissAddToTrackList(_ routeID: UUID) {
        closeCount += 1
        onDismiss?()
    }
}
