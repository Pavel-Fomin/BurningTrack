//
//  MoveToFolderFlowTests.swift
//  TrackListTests
//
//  Проверяет typed flow выбора папки, операции и защиту route-сеанса.
//
//  Created by Pavel Fomin on 15.08.2026.
//

import Foundation
import XCTest
@testable import TrackList

/// Проверяет Move To Folder без SheetManager.shared, файловой системы и production SQLite.
@MainActor
final class MoveToFolderFlowTests: XCTestCase {
    func testMoveScreenAppearedLoadsCurrentFolderThroughRegistry() async {
        let currentFolderID = UUID()
        let registry = MoveToFolderTrackRegistrySpy(
            entry: makeTrackEntry(folderID: currentFolderID)
        )
        let flow = makeFlow(registry: registry)

        flow.viewModel.send(.screenAppeared)
        await settleTaskQueue()

        XCTAssertEqual(flow.viewModel.state.currentFolderID, currentFolderID)
        let requestedTrackIDs = await registry.requestedTrackIDs
        XCTAssertEqual(requestedTrackIDs, [flow.track.trackId])
    }

    func testPurchasedITunesScreenAppearedDoesNotReadRegistry() async {
        let registry = MoveToFolderTrackRegistrySpy(entry: makeTrackEntry(folderID: UUID()))
        let purchasedTrack = makePurchasedTrack()
        let flow = makeFlow(
            operation: .copyPurchasedITunes,
            track: purchasedTrack,
            registry: registry
        )

        flow.viewModel.send(.screenAppeared)
        await settleTaskQueue()

        XCTAssertNil(flow.viewModel.state.currentFolderID)
        let requestedTrackIDs = await registry.requestedTrackIDs
        XCTAssertTrue(requestedTrackIDs.isEmpty)
    }

    func testFolderSelectionUsesTypedActionAndTogglesDestination() {
        let flow = makeFlow()
        let folderA = UUID()
        let folderB = UUID()

        flow.viewModel.send(.folderSelectionChanged(folderA))
        XCTAssertEqual(flow.viewModel.state.selectedFolderID, folderA)

        flow.viewModel.send(.folderSelectionChanged(nil))
        XCTAssertNil(flow.viewModel.state.selectedFolderID)

        flow.viewModel.send(.folderSelectionChanged(folderB))
        XCTAssertEqual(flow.viewModel.state.selectedFolderID, folderB)
    }

    func testCanSubmitRequiresValidDestinationAndIdleOperation() async {
        let currentFolderID = UUID()
        let destinationFolderID = UUID()
        let registry = MoveToFolderTrackRegistrySpy(
            entry: makeTrackEntry(folderID: currentFolderID)
        )
        let executor = MoveToFolderDeferredCommandExecutorSpy()
        let flow = makeFlow(registry: registry, executor: executor)

        XCTAssertFalse(flow.viewModel.state.canSubmit)

        flow.viewModel.send(.screenAppeared)
        await settleTaskQueue()
        flow.viewModel.send(.folderSelectionChanged(currentFolderID))
        XCTAssertFalse(flow.viewModel.state.canSubmit)

        flow.viewModel.send(.folderSelectionChanged(destinationFolderID))
        XCTAssertTrue(flow.viewModel.state.canSubmit)

        flow.viewModel.send(.submitTapped)
        await waitForMoveCallCount(1, from: executor)

        XCTAssertTrue(flow.viewModel.state.isPerformingOperation)
        XCTAssertFalse(flow.viewModel.state.canSubmit)

        executor.completeMove(
            with: .success(
                makeMoveSuccess(
                    trackID: flow.track.trackId,
                    destinationFolderID: destinationFolderID
                )
            )
        )
    }

    func testMoveSuccessUsesExactCommandArgumentsPresentsToastAndDismissesPayloadRoute() async {
        let destinationFolderID = UUID()
        let executor = MoveToFolderCommandExecutorSpy()
        let flow = makeFlow(executor: executor)
        executor.setMoveResult(
            .success(
                makeMoveSuccess(
                    trackID: flow.track.trackId,
                    destinationFolderID: destinationFolderID
                )
            )
        )

        flow.viewModel.send(.folderSelectionChanged(destinationFolderID))
        flow.viewModel.send(.submitTapped)
        await settleTaskQueue()

        let request = executor.moveRequests.first
        XCTAssertEqual(request?.trackID, flow.track.trackId)
        XCTAssertEqual(request?.destinationFolderID, destinationFolderID)
        XCTAssertEqual(request?.busyCheckerID, ObjectIdentifier(flow.busyChecker))
        XCTAssertEqual(flow.router.dismissedRouteIDs, [flow.data.id])
        XCTAssertEqual(flow.toast.events.count, 1)
        guard case .trackMovedInLibrary? = flow.toast.events.first else {
            return XCTFail("Должен быть показан success Toast перемещения")
        }
    }

    func testMoveAppErrorKeepsRouteOpenReturnsToIdleAndAllowsRetry() async {
        let destinationFolderID = UUID()
        let executor = MoveToFolderCommandExecutorSpy()
        let flow = makeFlow(executor: executor)
        executor.setMoveResult(.failure(AppError.fileNotFound))

        flow.viewModel.send(.folderSelectionChanged(destinationFolderID))
        flow.viewModel.send(.submitTapped)
        await settleTaskQueue()

        XCTAssertTrue(flow.router.dismissedRouteIDs.isEmpty)
        XCTAssertFalse(flow.viewModel.state.isPerformingOperation)
        XCTAssertTrue(flow.viewModel.state.canSubmit)
        guard case .fileNotFound? = flow.toast.errors.first else {
            return XCTFail("AppError должен остаться в AppCommandToastPresenter mapping")
        }

        executor.setMoveResult(
            .success(
                makeMoveSuccess(
                    trackID: flow.track.trackId,
                    destinationFolderID: destinationFolderID
                )
            )
        )
        flow.viewModel.send(.submitTapped)
        await settleTaskQueue()

        let moveRequestCount = executor.moveRequests.count
        XCTAssertEqual(moveRequestCount, 2)
        XCTAssertEqual(flow.router.dismissedRouteIDs, [flow.data.id])
    }

    func testMoveGenericErrorShowsFileMoveFailedAndKeepsRouteOpen() async {
        let executor = MoveToFolderCommandExecutorSpy()
        let flow = makeFlow(executor: executor)
        executor.setMoveResult(.failure(MoveToFolderTestError.failed))

        flow.viewModel.send(.folderSelectionChanged(UUID()))
        flow.viewModel.send(.submitTapped)
        await waitForToastErrorCount(1, from: flow.toast)

        guard case .fileMoveFailed? = flow.toast.errors.first else {
            return XCTFail("Generic move error должен сохранить AppError.fileMoveFailed")
        }
        XCTAssertTrue(flow.router.dismissedRouteIDs.isEmpty)
        XCTAssertFalse(flow.viewModel.state.isPerformingOperation)
    }

    func testPurchasedCopySuccessUsesPreparedPayloadAndDismissesPayloadRoute() async {
        let destinationFolderID = UUID()
        let purchasedTrack = makePurchasedTrack()
        let executor = MoveToFolderCommandExecutorSpy()
        let flow = makeFlow(
            operation: .copyPurchasedITunes,
            track: purchasedTrack,
            executor: executor
        )
        executor.setCopyResult(
            .success(
                CopyPurchasedITunesTrackSuccess(
                    sourceTrackId: purchasedTrack.trackId,
                    copiedFileURL: URL(fileURLWithPath: "/tmp/copied.m4a"),
                    destinationFolderId: destinationFolderID,
                    destinationFolderName: "Destination"
                )
            )
        )

        flow.viewModel.send(.folderSelectionChanged(destinationFolderID))
        flow.viewModel.send(.submitTapped)
        await settleTaskQueue()

        let request = executor.copyRequests.first
        XCTAssertEqual(request?.trackID, purchasedTrack.trackId)
        XCTAssertEqual(request?.destinationFolderID, destinationFolderID)
        XCTAssertEqual(flow.router.dismissedRouteIDs, [flow.data.id])
        guard case .trackCopiedFromITunes? = flow.toast.events.first else {
            return XCTFail("Должен быть показан success Toast копирования iTunes")
        }
    }

    func testInvalidPurchasedPayloadShowsPreparationFailureWithoutCommandOrDismiss() async {
        let executor = MoveToFolderCommandExecutorSpy()
        let flow = makeFlow(operation: .copyPurchasedITunes, executor: executor)

        flow.viewModel.send(.folderSelectionChanged(UUID()))
        flow.viewModel.send(.submitTapped)

        XCTAssertFalse(flow.viewModel.state.isPerformingOperation)
        XCTAssertEqual(
            flow.toast.events,
            [
                .operationFailed(
                    message: MoveToFolderPresentationText
                        .purchasedITunesTrackPreparationFailedMessage
                )
            ]
        )
        XCTAssertTrue(flow.router.dismissedRouteIDs.isEmpty)
        let moveRequests = executor.moveRequests
        let copyRequests = executor.copyRequests
        XCTAssertTrue(moveRequests.isEmpty)
        XCTAssertTrue(copyRequests.isEmpty)
    }

    func testPurchasedCopyAppErrorKeepsRouteOpenAndReturnsToIdle() async {
        let executor = MoveToFolderCommandExecutorSpy()
        let flow = makeFlow(
            operation: .copyPurchasedITunes,
            track: makePurchasedTrack(),
            executor: executor
        )
        executor.setCopyResult(.failure(AppError.purchasedITunesCopyFailed))

        flow.viewModel.send(.folderSelectionChanged(UUID()))
        flow.viewModel.send(.submitTapped)
        await settleTaskQueue()

        XCTAssertFalse(flow.viewModel.state.isPerformingOperation)
        XCTAssertTrue(flow.router.dismissedRouteIDs.isEmpty)
        guard case .purchasedITunesCopyFailed? = flow.toast.errors.first else {
            return XCTFail("AppError копирования должен быть передан AppCommandToastPresenter")
        }
    }

    func testPurchasedCopyGenericErrorShowsExistingMessageAndKeepsRouteOpen() async {
        let executor = MoveToFolderCommandExecutorSpy()
        let flow = makeFlow(
            operation: .copyPurchasedITunes,
            track: makePurchasedTrack(),
            executor: executor
        )
        executor.setCopyResult(.failure(MoveToFolderTestError.failed))

        flow.viewModel.send(.folderSelectionChanged(UUID()))
        flow.viewModel.send(.submitTapped)
        await settleTaskQueue()

        XCTAssertEqual(
            flow.toast.events,
            [
                .operationFailed(
                    message: MoveToFolderPresentationText
                        .purchasedITunesTrackCopyFailedMessage
                )
            ]
        )
        XCTAssertTrue(flow.router.dismissedRouteIDs.isEmpty)
    }

    func testRepeatedSubmitStartsOnlyOneDomainCommand() async {
        let executor = MoveToFolderDeferredCommandExecutorSpy()
        let flow = makeFlow(executor: executor)
        let destinationFolderID = UUID()

        flow.viewModel.send(.folderSelectionChanged(destinationFolderID))
        flow.viewModel.send(.submitTapped)
        flow.viewModel.send(.submitTapped)
        await waitForMoveCallCount(1, from: executor)

        let moveRequestCount = executor.moveRequestCount
        XCTAssertEqual(moveRequestCount, 1)

        executor.completeMove(
            with: .success(
                makeMoveSuccess(
                    trackID: flow.track.trackId,
                    destinationFolderID: destinationFolderID
                )
            )
        )
    }

    func testCloseDuringOperationKeepsDomainCommandButSuppressesLateCompletion() async {
        let executor = MoveToFolderDeferredCommandExecutorSpy()
        let flow = makeFlow(executor: executor)
        let destinationFolderID = UUID()

        flow.viewModel.send(.folderSelectionChanged(destinationFolderID))
        flow.viewModel.send(.submitTapped)
        await waitForMoveCallCount(1, from: executor)
        flow.viewModel.send(.closeTapped)

        executor.completeMove(
            with: .success(
                makeMoveSuccess(
                    trackID: flow.track.trackId,
                    destinationFolderID: destinationFolderID
                )
            )
        )
        await settleTaskQueue()

        let moveRequestCount = executor.moveRequestCount
        XCTAssertEqual(moveRequestCount, 1)
        XCTAssertEqual(flow.router.dismissedRouteIDs, [flow.data.id])
        XCTAssertTrue(flow.toast.events.isEmpty)
        XCTAssertTrue(flow.toast.errors.isEmpty)
    }

    func testSheetDisappearedDuringOperationSuppressesLateCompletionAndRouteMutation() async {
        let executor = MoveToFolderDeferredCommandExecutorSpy()
        let flow = makeFlow(executor: executor)
        let destinationFolderID = UUID()

        flow.viewModel.send(.folderSelectionChanged(destinationFolderID))
        flow.viewModel.send(.submitTapped)
        await waitForMoveCallCount(1, from: executor)
        flow.viewModel.send(.sheetDisappeared)

        executor.completeMove(
            with: .success(
                makeMoveSuccess(
                    trackID: flow.track.trackId,
                    destinationFolderID: destinationFolderID
                )
            )
        )
        await settleTaskQueue()

        XCTAssertTrue(flow.router.dismissedRouteIDs.isEmpty)
        XCTAssertTrue(flow.toast.events.isEmpty)
        XCTAssertTrue(flow.toast.errors.isEmpty)
    }

    func testInitialLoadCompletionAfterSheetDisappearedDoesNotPublishCurrentFolder() async {
        let registry = MoveToFolderDeferredTrackRegistrySpy()
        let flow = makeFlow(registry: registry)
        let currentFolderID = UUID()

        flow.viewModel.send(.screenAppeared)
        await waitForRegistryRequestCount(1, from: registry)
        flow.viewModel.send(.sheetDisappeared)
        await registry.completeFirst(with: makeTrackEntry(folderID: currentFolderID))
        await settleTaskQueue()

        XCTAssertNil(flow.viewModel.state.currentFolderID)
    }

    func testNavigationContextUsesSnapshotForRootChildrenLeafAndCurrentFolderSemantics() {
        let rootID = UUID()
        let currentID = UUID()
        let leafID = UUID()
        let secondRootID = UUID()
        let snapshot = MoveToFolderFolderSnapshot(
            rootNodes: [
                MoveToFolderFolderNode(
                    id: rootID,
                    name: "Root",
                    children: [
                        MoveToFolderFolderNode(
                            id: currentID,
                            name: "Current",
                            children: []
                        ),
                        MoveToFolderFolderNode(
                            id: leafID,
                            name: "Leaf",
                            children: []
                        )
                    ]
                ),
                MoveToFolderFolderNode(
                    id: secondRootID,
                    name: "Second Root",
                    children: []
                )
            ]
        )
        let navigation = MoveToFolderNavigationContext(snapshot: snapshot)

        XCTAssertEqual(
            navigation.rows(currentFolderID: currentID).map(\.id),
            [currentID, rootID, secondRootID]
        )
        navigation.enter(rootID)
        XCTAssertTrue(navigation.canGoBack)
        XCTAssertEqual(navigation.currentFolderName, "Root")
        XCTAssertEqual(
            navigation.rows(currentFolderID: currentID).map(\.id),
            [currentID, leafID]
        )
        navigation.enter(leafID)
        XCTAssertEqual(navigation.currentFolderID, rootID)

        navigation.goBack()
        XCTAssertFalse(navigation.canGoBack)
        XCTAssertEqual(navigation.rows(currentFolderID: rootID).map(\.id), [rootID, secondRootID])
    }

    private func makeFlow(
        operation: MoveToFolderOperation = .move,
        track: any TrackDisplayable = MoveToFolderLocalTrack(),
        registry: any MoveToFolderTrackRegistryReading = MoveToFolderTrackRegistrySpy(entry: nil),
        executor: any MoveToFolderCommandExecuting = MoveToFolderCommandExecutorSpy(),
        snapshot: MoveToFolderFolderSnapshot = MoveToFolderFolderSnapshot(rootNodes: [])
    ) -> MoveToFolderTestFlow {
        let data = MoveToFolderSheetData(track: track, operation: operation)
        let presenter = MoveToFolderPresenter()
        let initialState = presenter.makeState(
            navigationTitle: MoveToFolderPresentationText.title(for: operation),
            folderSnapshot: snapshot,
            selectedFolderID: nil,
            currentFolderID: nil,
            isPerformingOperation: false
        )
        let viewModel = MoveToFolderViewModel(initialState: initialState)
        let busyChecker = MoveToFolderBusyCheckerSpy()
        let toast = MoveToFolderToastPresenterSpy()
        let router = MoveToFolderRouterSpy()
        let actionHandler = MoveToFolderActionHandler(
            data: data,
            folderSnapshot: snapshot,
            trackRegistry: registry,
            fileBusyChecker: busyChecker,
            commandExecutor: executor,
            toastPresenter: toast,
            router: router,
            presenter: presenter
        )
        presenter.configure(output: viewModel)
        viewModel.configure(actionHandler: actionHandler)

        return MoveToFolderTestFlow(
            data: data,
            track: track,
            viewModel: viewModel,
            busyChecker: busyChecker,
            toast: toast,
            router: router
        )
    }

    private func makeTrackEntry(folderID: UUID?) -> TrackRegistry.TrackEntry {
        TrackRegistry.TrackEntry(
            id: UUID(),
            fileName: "Track.mp3",
            relativePath: "Track.mp3",
            folderId: folderID,
            rootFolderId: nil,
            importedAt: Date(),
            fileDate: Date(),
            updatedAt: Date()
        )
    }

    private func makeMoveSuccess(
        trackID: UUID,
        destinationFolderID: UUID
    ) -> MoveTrackSuccess {
        MoveTrackSuccess(
            trackId: trackID,
            destinationFolderId: destinationFolderID,
            destinationFolderName: "Destination",
            snapshot: nil
        )
    }

    private func makePurchasedTrack() -> MoveToFolderPurchasedTrack {
        MoveToFolderPurchasedTrack(
            id: UUID(),
            trackID: UUID(),
            fileName: "Purchased.m4a",
            title: "Purchased",
            artist: "Artist",
            assetURL: URL(fileURLWithPath: "/tmp/purchased.m4a")
        )
    }

    private func settleTaskQueue() async {
        for _ in 0..<16 {
            await Task.yield()
        }
    }

    private func waitForMoveCallCount(
        _ expectedCount: Int,
        from executor: MoveToFolderDeferredCommandExecutorSpy
    ) async {
        for _ in 0..<128 {
            if executor.moveRequestCount >= expectedCount {
                return
            }
            await Task.yield()
        }

        XCTFail("Move command не была запущена")
    }

    private func waitForRegistryRequestCount(
        _ expectedCount: Int,
        from registry: MoveToFolderDeferredTrackRegistrySpy
    ) async {
        for _ in 0..<128 {
            if await registry.requestedTrackIDs.count >= expectedCount {
                return
            }
            await Task.yield()
        }

        XCTFail("TrackRegistry initial load не была запущена")
    }

    /// Ожидает опубликованную ошибку вместо предположения о числе actor scheduler yield.
    private func waitForToastErrorCount(
        _ expectedCount: Int,
        from toast: MoveToFolderToastPresenterSpy
    ) async {
        for _ in 0..<128 {
            if toast.errors.count >= expectedCount {
                return
            }
            await Task.yield()
        }

        XCTFail("Toast error не был опубликован")
    }
}

/// Объединяет test-visible части feature graph одного immutable route.
@MainActor
private struct MoveToFolderTestFlow {
    let data: MoveToFolderSheetData
    let track: any TrackDisplayable
    let viewModel: MoveToFolderViewModel
    let busyChecker: MoveToFolderBusyCheckerSpy
    let toast: MoveToFolderToastPresenterSpy
    let router: MoveToFolderRouterSpy
}

/// Представляет local track без зависимости тестов от SQLite модели.
private struct MoveToFolderLocalTrack: TrackDisplayable {
    let id = UUID()
    let trackId = UUID()
    let fileName = "Local.mp3"
    let title: String? = "Local"
    let artist: String? = "Artist"
    let duration = 180.0
    let isAvailable = true
}

/// Представляет готовый iTunes runtime source с assetURL без обращения к MediaPlayer.
private struct MoveToFolderPurchasedTrack: TrackDisplayable, PurchasedITunesTrackRepresentable {
    let id: UUID
    let trackId: UUID
    let fileName: String
    let title: String?
    let artist: String?
    let duration = 180.0
    let isAvailable = true
    let source: TrackSource = .purchasedITunes
    let album: String? = nil
    let artworkData: Data? = nil
    let purchasedITunesAssetURL: URL?

    init(
        id: UUID,
        trackID: UUID,
        fileName: String,
        title: String?,
        artist: String?,
        assetURL: URL
    ) {
        self.id = id
        trackId = trackID
        self.fileName = fileName
        self.title = title
        self.artist = artist
        purchasedITunesAssetURL = assetURL
    }
}

/// Фиксирует текущую папку без production TrackRegistry.
private actor MoveToFolderTrackRegistrySpy: MoveToFolderTrackRegistryReading {
    private let entryResult: TrackRegistry.TrackEntry?
    private(set) var requestedTrackIDs: [UUID] = []

    init(entry: TrackRegistry.TrackEntry?) {
        entryResult = entry
    }

    func entry(for id: UUID) async -> TrackRegistry.TrackEntry? {
        requestedTrackIDs.append(id)
        return entryResult
    }
}

/// Удерживает initial lookup до явного completion для проверки late-result защиты.
private actor MoveToFolderDeferredTrackRegistrySpy: MoveToFolderTrackRegistryReading {
    private var continuations: [CheckedContinuation<TrackRegistry.TrackEntry?, Never>] = []
    private(set) var requestedTrackIDs: [UUID] = []

    func entry(for id: UUID) async -> TrackRegistry.TrackEntry? {
        requestedTrackIDs.append(id)
        return await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func completeFirst(with entry: TrackRegistry.TrackEntry?) {
        guard continuations.isEmpty == false else { return }
        continuations.removeFirst().resume(returning: entry)
    }
}

/// MainActor-double фиксирует точные аргументы Move To Folder в едином command flow.
@MainActor
private final class MoveToFolderCommandExecutorSpy: MoveToFolderCommandExecuting {
    struct MoveRequest {
        let trackID: UUID
        let destinationFolderID: UUID
        let busyCheckerID: ObjectIdentifier
    }

    struct CopyRequest {
        let trackID: UUID
        let destinationFolderID: UUID
    }

    private var moveResult: Result<MoveTrackSuccess, Error> = .failure(MoveToFolderTestError.failed)
    private var copyResult: Result<CopyPurchasedITunesTrackSuccess, Error> = .failure(MoveToFolderTestError.failed)
    private(set) var moveRequests: [MoveRequest] = []
    private(set) var copyRequests: [CopyRequest] = []

    func setMoveResult(_ result: Result<MoveTrackSuccess, Error>) {
        moveResult = result
    }

    func setCopyResult(_ result: Result<CopyPurchasedITunesTrackSuccess, Error>) {
        copyResult = result
    }

    func moveTrack(
        trackId: UUID,
        toFolder folderID: UUID,
        using fileBusyChecker: any TrackFileBusyChecking
    ) async throws -> MoveTrackSuccess {
        moveRequests.append(
            MoveRequest(
                trackID: trackId,
                destinationFolderID: folderID,
                busyCheckerID: ObjectIdentifier(fileBusyChecker)
            )
        )
        return try moveResult.get()
    }

    func copyPurchasedITunesTrack(
        _ track: PurchasedITunesPlayableTrack,
        toFolder folderID: UUID
    ) async throws -> CopyPurchasedITunesTrackSuccess {
        copyRequests.append(
            CopyRequest(trackID: track.trackId, destinationFolderID: folderID)
        )
        return try copyResult.get()
    }
}

/// Удерживает move command на MainActor после submit, чтобы проверить repeated и stale completion сценарии.
@MainActor
private final class MoveToFolderDeferredCommandExecutorSpy: MoveToFolderCommandExecuting {
    private var moveContinuations: [CheckedContinuation<Result<MoveTrackSuccess, Error>, Never>] = []
    private(set) var moveRequestCount = 0

    func moveTrack(
        trackId _: UUID,
        toFolder _: UUID,
        using _: any TrackFileBusyChecking
    ) async throws -> MoveTrackSuccess {
        moveRequestCount += 1
        let result = await withCheckedContinuation { continuation in
            moveContinuations.append(continuation)
        }
        return try result.get()
    }

    func copyPurchasedITunesTrack(
        _ track: PurchasedITunesPlayableTrack,
        toFolder folderID: UUID
    ) async throws -> CopyPurchasedITunesTrackSuccess {
        CopyPurchasedITunesTrackSuccess(
            sourceTrackId: track.trackId,
            copiedFileURL: track.assetURL,
            destinationFolderId: folderID,
            destinationFolderName: nil
        )
    }

    func completeMove(with result: Result<MoveTrackSuccess, Error>) {
        guard moveContinuations.isEmpty == false else { return }
        moveContinuations.removeFirst().resume(returning: result)
    }
}

/// Передаёт file busy capability в command spy без реализации player behavior.
@MainActor
private final class MoveToFolderBusyCheckerSpy: TrackFileBusyChecking {
    func isTrackFileBusy(trackId _: UUID) -> Bool {
        false
    }
}

/// Запоминает toast mapping без UIKit presentation.
@MainActor
private final class MoveToFolderToastPresenterSpy: ToastPresenting {
    private(set) var events: [ToastEvent] = []
    private(set) var errors: [AppError] = []

    func handle(_ event: ToastEvent, duration _: TimeInterval) {
        events.append(event)
    }

    func handle(_ error: AppError) {
        errors.append(error)
    }
}

/// Фиксирует route identity вместо обращения к SheetManager.
@MainActor
private final class MoveToFolderRouterSpy: MoveToFolderRouting {
    private(set) var dismissedRouteIDs: [UUID] = []

    func dismissMoveToFolder(_ routeID: UUID) {
        dismissedRouteIDs.append(routeID)
    }
}

/// Представляет generic command failure, который не должен попасть в AppError mapping.
private enum MoveToFolderTestError: Error {
    case failed
}
