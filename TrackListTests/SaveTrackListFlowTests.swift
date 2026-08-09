//
//  SaveTrackListFlowTests.swift
//  TrackList
//
//  Focused-проверки flow сохранения очереди плеера в треклист.
//
//  Created by Pavel Fomin on 04.08.2026.
//

import Foundation
import XCTest
@testable import TrackList

/// Проверяет ViewModel и ActionHandler Save TrackList через явные feature-зависимости.
@MainActor
final class SaveTrackListFlowTests: XCTestCase {

    func testInitialStateKeepsCurrentDefaultName() {
        let (viewModel, _, _, _) = makeViewModel(initialName: "Current Queue")

        XCTAssertEqual(viewModel.state.name, "Current Queue")
        XCTAssertTrue(viewModel.state.canSubmit)
        XCTAssertFalse(viewModel.state.isSubmitting)
    }

    func testEmptyNameDoesNotAllowSubmit() {
        let (viewModel, service, _, _) = makeViewModel(initialName: "Current Queue")

        viewModel.handle(.nameChanged(""))
        viewModel.handle(.submit)

        XCTAssertFalse(viewModel.state.canSubmit)
        XCTAssertTrue(service.requests.isEmpty)
    }

    func testWhitespaceOnlyNameDoesNotAllowSubmit() {
        let (viewModel, service, _, _) = makeViewModel(initialName: "Current Queue")

        viewModel.handle(.nameChanged(" \n "))
        viewModel.handle(.submit)

        XCTAssertFalse(viewModel.state.canSubmit)
        XCTAssertTrue(service.requests.isEmpty)
    }

    func testNameChangedUpdatesStateAndAllowsValidSubmit() {
        let (viewModel, _, _, _) = makeViewModel(initialName: "")

        viewModel.handle(.nameChanged("Road Trip"))

        XCTAssertEqual(viewModel.state.name, "Road Trip")
        XCTAssertTrue(viewModel.state.canSubmit)
    }

    func testRepeatedSubmitIsIgnoredWhileOperationIsScheduled() async {
        let (viewModel, service, _, _) = makeViewModel(initialName: "Queue")

        viewModel.handle(.submit)
        viewModel.handle(.submit)

        XCTAssertTrue(viewModel.state.isSubmitting)
        await completeScheduledTask()

        XCTAssertEqual(service.requests.count, 1)
    }

    func testCancelClosesFlowThroughExplicitRouter() {
        let (viewModel, _, _, router) = makeViewModel(initialName: "Queue")

        viewModel.handle(.cancel)

        XCTAssertEqual(router.closeCount, 1)
    }

    func testEmptyQueueRemainsAllowedByCurrentFlow() {
        let queue = SaveTrackListQueueSpy(tracks: [])
        let service = SaveTrackListServiceSpy()
        let handler = makeActionHandler(queue: queue, service: service)

        let result = handler.submit(name: "Empty Queue")

        XCTAssertEqual(result, .success)
        XCTAssertEqual(service.requests.first?.trackIDs, [])
    }

    func testSubmitReadsLiveQueueAtConfirmationTimeAndPreservesOrder() async {
        let first = makeTrack(fileName: "First.mp3")
        let second = makeTrack(fileName: "Second.mp3")
        let queue = SaveTrackListQueueSpy(tracks: [first])
        let service = SaveTrackListServiceSpy()
        let (viewModel, _, _, _) = makeViewModel(
            initialName: "Live Queue",
            queue: queue,
            service: service
        )
        queue.tracks = [second, first]

        viewModel.handle(.submit)
        await completeScheduledTask()

        XCTAssertEqual(queue.readCount, 1)
        XCTAssertEqual(service.requests.first?.trackIDs, [second.trackId, first.trackId])
    }

    func testHandlerInvokesDomainCommandWithNormalizedNameAndFullQueue() {
        let first = makeTrack(fileName: "First.mp3")
        let second = makeTrack(fileName: "Second.mp3")
        let queue = SaveTrackListQueueSpy(tracks: [first, second])
        let service = SaveTrackListServiceSpy()
        let handler = makeActionHandler(queue: queue, service: service)

        let result = handler.submit(name: "  Evening Set  ")

        XCTAssertEqual(result, .success)
        XCTAssertEqual(service.requests.count, 1)
        XCTAssertEqual(service.requests.first?.name, "Evening Set")
        XCTAssertEqual(service.requests.first?.trackIDs, [first.trackId, second.trackId])
    }

    func testSuccessShowsCurrentToastAndClosesSheet() {
        let toast = SaveTrackListToastSpy()
        let router = SaveTrackListRouterSpy()
        let handler = makeActionHandler(
            queue: SaveTrackListQueueSpy(tracks: [makeTrack(fileName: "Queue.mp3")]),
            service: SaveTrackListServiceSpy(),
            toast: toast,
            router: router
        )

        _ = handler.submit(name: "Saved Queue")

        XCTAssertEqual(toast.events, [.trackListSaved(name: "Saved Queue")])
        XCTAssertEqual(router.closeCount, 1)
    }

    func testErrorShowsCurrentMessageAndKeepsSheetOpen() {
        let service = SaveTrackListServiceSpy()
        service.error = AppError.trackListSaveFailed
        let toast = SaveTrackListToastSpy()
        let router = SaveTrackListRouterSpy()
        let handler = makeActionHandler(
            queue: SaveTrackListQueueSpy(tracks: [makeTrack(fileName: "Queue.mp3")]),
            service: service,
            toast: toast,
            router: router
        )

        let result = handler.submit(name: "Saved Queue")

        XCTAssertEqual(result, .failure)
        XCTAssertEqual(router.closeCount, 0)
        guard case .trackListSaveFailed? = toast.errors.first else {
            return XCTFail("Должна быть показана текущая ошибка сохранения треклиста")
        }
    }

    func testFailureResetsSubmittingStateAndAllowsRetry() async {
        let service = SaveTrackListServiceSpy()
        service.error = AppError.trackListSaveFailed
        let (viewModel, _, _, router) = makeViewModel(
            initialName: "Retry Queue",
            service: service
        )

        viewModel.handle(.submit)
        await completeScheduledTask()

        XCTAssertFalse(viewModel.state.isSubmitting)
        XCTAssertTrue(viewModel.state.canSubmit)
        XCTAssertEqual(router.closeCount, 0)

        service.error = nil
        viewModel.handle(.submit)
        await completeScheduledTask()

        XCTAssertEqual(service.requests.count, 1)
        XCTAssertEqual(service.attemptCount, 2)
        XCTAssertEqual(router.closeCount, 1)
    }

    func testHandlerUsesOnlyInjectedDependencies() {
        let queue = SaveTrackListQueueSpy(tracks: [makeTrack(fileName: "Queue.mp3")])
        let service = SaveTrackListServiceSpy()
        let toast = SaveTrackListToastSpy()
        let router = SaveTrackListRouterSpy()
        let handler = makeActionHandler(
            queue: queue,
            service: service,
            toast: toast,
            router: router
        )

        _ = handler.submit(name: "Injected")

        XCTAssertEqual(queue.readCount, 1)
        XCTAssertEqual(service.requests.count, 1)
        XCTAssertEqual(toast.events, [.trackListSaved(name: "Injected")])
        XCTAssertEqual(router.closeCount, 1)
    }

    private func makeViewModel(
        initialName: String,
        queue: SaveTrackListQueueSpy? = nil,
        service: SaveTrackListServiceSpy? = nil,
        toast: SaveTrackListToastSpy? = nil,
        router: SaveTrackListRouterSpy? = nil
    ) -> (
        SaveTrackListViewModel,
        SaveTrackListServiceSpy,
        SaveTrackListToastSpy,
        SaveTrackListRouterSpy
    ) {
        let resolvedQueue = queue ?? SaveTrackListQueueSpy(
            tracks: [makeTrack(fileName: "Queue.mp3")]
        )
        let resolvedService = service ?? SaveTrackListServiceSpy()
        let resolvedToast = toast ?? SaveTrackListToastSpy()
        let resolvedRouter = router ?? SaveTrackListRouterSpy()
        let handler = makeActionHandler(
            queue: resolvedQueue,
            service: resolvedService,
            toast: resolvedToast,
            router: resolvedRouter
        )
        let viewModel = SaveTrackListViewModel(
            initialName: initialName,
            stateBuilder: SaveTrackListStateBuilder(),
            actionHandler: handler
        )

        return (viewModel, resolvedService, resolvedToast, resolvedRouter)
    }

    private func makeActionHandler(
        queue: SaveTrackListQueueSpy,
        service: SaveTrackListServiceSpy,
        toast: SaveTrackListToastSpy? = nil,
        router: SaveTrackListRouterSpy? = nil
    ) -> SaveTrackListActionHandler {
        let resolvedToast = toast ?? SaveTrackListToastSpy()
        let resolvedRouter = router ?? SaveTrackListRouterSpy()

        return SaveTrackListActionHandler(
            queueProvider: queue,
            trackListsService: service,
            toastPresenter: resolvedToast,
            router: resolvedRouter
        )
    }

    private func makeTrack(fileName: String) -> Track {
        Track(
            trackId: UUID(),
            title: fileName,
            artist: "Artist",
            duration: 120,
            fileName: fileName,
            isAvailable: true
        )
    }

    private func completeScheduledTask() async {
        for _ in 0 ..< 5 {
            await Task.yield()
        }
    }
}

/// Возвращает изменяемый снимок очереди и фиксирует момент её чтения.
@MainActor
private final class SaveTrackListQueueSpy: SaveTrackListQueueProviding {
    var tracks: [Track]
    private(set) var readCount = 0

    init(tracks: [Track]) {
        self.tracks = tracks
    }

    func currentQueueTracks() -> [Track] {
        readCount += 1
        return tracks
    }
}

/// Запоминает доменную команду сохранения без обращения к production-менеджеру.
@MainActor
private final class SaveTrackListServiceSpy: SaveTrackListCreating {
    struct Request: Equatable {
        let name: String
        let trackIDs: [UUID]
    }

    var error: Error?
    private(set) var attemptCount = 0
    private(set) var requests: [Request] = []

    func createTrackList(
        from tracks: [Track],
        withName name: String
    ) throws -> TrackList {
        attemptCount += 1

        if let error {
            throw error
        }

        requests.append(
            Request(
                name: name,
                trackIDs: tracks.map(\.trackId)
            )
        )
        return TrackList(
            id: UUID(),
            name: name,
            createdAt: Date(),
            kind: .regular,
            tracks: tracks
        )
    }
}

/// Запоминает presentation-сообщения Save TrackList flow.
@MainActor
private final class SaveTrackListToastSpy: ToastPresenting {
    private(set) var events: [ToastEvent] = []
    private(set) var errors: [AppError] = []

    func handle(_ event: ToastEvent, duration: TimeInterval) {
        events.append(event)
    }

    func handle(_ error: AppError) {
        errors.append(error)
    }
}

/// Проверяет закрытие Save TrackList без зависимости от SheetManager.
@MainActor
private final class SaveTrackListRouterSpy: SaveTrackListRouting {
    private(set) var closeCount = 0

    func dismissSaveTrackList(_ routeID: UUID) {
        closeCount += 1
    }
}
