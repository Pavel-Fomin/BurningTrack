//
//  LibraryTracksViewModelBackgroundDetailsTests.swift
//  TrackList
//
//  Controlled XCTest для ownership фоновой догрузки Library Tracks.
//
//  Created by Pavel Fomin on 21.08.2026.
//

import Combine
import Foundation
import XCTest
@testable import TrackList

final class LibraryTracksViewModelBackgroundDetailsTests: XCTestCase {

    private var database: AppDatabase?
    private var databaseDirectory: URL?

    override func tearDownWithError() throws {
        // Временная SQLite-база закрывается до удаления WAL и SHM файлов.
        try database?.close()
        database = nil

        if let databaseDirectory {
            try? FileManager.default.removeItem(at: databaseDirectory)
        }
        databaseDirectory = nil

        try super.tearDownWithError()
    }

    @MainActor
    func testNewRefreshCancelsPreviousDetailsAndLateCompletionKeepsCurrentTaskOwned() async throws {
        let firstTrack = makeTrack(title: "First", isAvailable: false)
        let secondTrack = makeTrack(title: "Second", isAvailable: false)
        let thirdTrack = makeTrack(title: "Third", isAvailable: false)
        let tracksProvider = ControlledLibraryTracksProvider(
            responses: [[firstTrack], [secondTrack], [thirdTrack]]
        )
        let urlProvider = ControlledTrackURLProvider()
        let viewModel = try makeViewModel(
            tracksProvider: tracksProvider,
            source: .folder(folderId: UUID()),
            trackURLProvider: urlProvider
        )

        await viewModel.refresh()
        await urlProvider.waitForRequestCount(1)

        await viewModel.refresh()
        await urlProvider.waitForRequestCount(2)

        // Поздний completion A должен завершиться, не очищая reference на ещё активную B-задачу.
        await urlProvider.resumeFirst(for: firstTrack.trackId, isAvailable: false)
        await urlProvider.waitForReturnCount(1)
        let firstCancellation = await urlProvider.cancellationStatuses(for: firstTrack.trackId)
        XCTAssertEqual(firstCancellation, [true])
        await Task.yield()

        await viewModel.refresh()
        await urlProvider.waitForRequestCount(3)

        await urlProvider.resumeFirst(for: secondTrack.trackId, isAvailable: false)
        await urlProvider.waitForReturnCount(2)
        let secondCancellation = await urlProvider.cancellationStatuses(for: secondTrack.trackId)
        XCTAssertEqual(secondCancellation, [true])
        await urlProvider.resumeFirst(for: thirdTrack.trackId, isAvailable: true)
        await Task.yield()

        XCTAssertEqual(viewModel.trackSections.flatMap(\.tracks).map(\.id), [thirdTrack.id])
    }

    @MainActor
    func testLateAvailabilityFromPreviousRefreshDoesNotOverwriteNewList() async throws {
        let firstTrack = makeTrack(title: "Old", isAvailable: false)
        let secondTrack = makeTrack(title: "Current", isAvailable: false)
        let tracksProvider = ControlledLibraryTracksProvider(
            responses: [[firstTrack], [secondTrack]]
        )
        let urlProvider = ControlledTrackURLProvider()
        let viewModel = try makeViewModel(
            tracksProvider: tracksProvider,
            source: .folder(folderId: UUID()),
            trackURLProvider: urlProvider
        )
        let availabilityExpectation = expectation(
            description: "Availability текущего списка применена"
        )
        let cancellable = viewModel.$trackSections
            .dropFirst()
            .sink { sections in
                guard sections.flatMap(\.tracks).first?.id == secondTrack.id,
                      sections.flatMap(\.tracks).first?.isAvailable == true else {
                    return
                }

                availabilityExpectation.fulfill()
            }

        await viewModel.refresh()
        await urlProvider.waitForRequestCount(1)

        await viewModel.refresh()
        await urlProvider.waitForRequestCount(2)
        await urlProvider.resumeFirst(for: secondTrack.trackId, isAvailable: true)
        await fulfillment(of: [availabilityExpectation], timeout: 1)

        await urlProvider.resumeFirst(for: firstTrack.trackId, isAvailable: false)
        await urlProvider.waitForReturnCount(2)
        let firstCancellation = await urlProvider.cancellationStatuses(for: firstTrack.trackId)
        XCTAssertEqual(firstCancellation, [true])
        await Task.yield()

        XCTAssertEqual(viewModel.trackSections.flatMap(\.tracks).map(\.id), [secondTrack.id])
        XCTAssertEqual(viewModel.trackSections.flatMap(\.tracks).first?.isAvailable, true)
        withExtendedLifetime(cancellable) {}
    }

    @MainActor
    func testSameRowIdentityFromPreviousRefreshCannotOverwriteCurrentAvailability() async throws {
        let sharedRowID = UUID()
        let oldTrack = makeTrack(
            id: sharedRowID,
            title: "Old revision",
            isAvailable: false
        )
        let currentTrack = makeTrack(
            id: sharedRowID,
            title: "Current revision",
            isAvailable: false
        )
        let tracksProvider = ControlledLibraryTracksProvider(
            responses: [[oldTrack], [currentTrack]]
        )
        let urlProvider = ControlledTrackURLProvider()
        let viewModel = try makeViewModel(
            tracksProvider: tracksProvider,
            source: .folder(folderId: UUID()),
            trackURLProvider: urlProvider
        )
        let availabilityExpectation = expectation(
            description: "Availability текущей строки применена"
        )
        let cancellable = viewModel.$trackSections
            .dropFirst()
            .sink { sections in
                guard sections.flatMap(\.tracks).first?.isAvailable == true else {
                    return
                }

                availabilityExpectation.fulfill()
            }

        await viewModel.refresh()
        await urlProvider.waitForRequestCount(1)

        await viewModel.refresh()
        await urlProvider.waitForRequestCount(2)
        await urlProvider.resumeLast(for: sharedRowID, isAvailable: true)
        await fulfillment(of: [availabilityExpectation], timeout: 1)

        await urlProvider.resumeFirst(for: sharedRowID, isAvailable: false)
        await urlProvider.waitForReturnCount(2)
        let cancellationStatuses = await urlProvider.cancellationStatuses(for: sharedRowID)
        XCTAssertEqual(cancellationStatuses, [false, true])
        await Task.yield()

        XCTAssertEqual(viewModel.trackSections.flatMap(\.tracks).map(\.id), [sharedRowID])
        XCTAssertEqual(viewModel.trackSections.flatMap(\.tracks).first?.isAvailable, true)
        withExtendedLifetime(cancellable) {}
    }

    @MainActor
    func testDeinitCancelsBackgroundTaskWithoutRetainingViewModel() async throws {
        let track = makeTrack(title: "Retained only by screen", isAvailable: false)
        let tracksProvider = ControlledLibraryTracksProvider(responses: [[track]])
        let urlProvider = ControlledTrackURLProvider()
        weak var weakViewModel: LibraryTracksViewModel?

        var viewModel: LibraryTracksViewModel? = try makeViewModel(
            tracksProvider: tracksProvider,
            source: .folder(folderId: UUID()),
            trackURLProvider: urlProvider
        )
        weakViewModel = viewModel

        await viewModel?.refresh()
        await urlProvider.waitForRequestCount(1)

        viewModel = nil

        XCTAssertNil(weakViewModel)

        await urlProvider.resumeFirst(for: track.trackId, isAvailable: false)
        await urlProvider.waitForReturnCount(1)
        let cancellationStatuses = await urlProvider.cancellationStatuses(for: track.trackId)
        XCTAssertEqual(cancellationStatuses, [true])
        await Task.yield()

        XCTAssertNil(weakViewModel)
    }

    @MainActor
    func testCancelledDetailsTaskStopsRemainingURLLookups() async throws {
        let firstTrack = makeTrack(title: "First", isAvailable: false)
        let secondTrack = makeTrack(title: "Second", isAvailable: false)
        let thirdTrack = makeTrack(title: "Third", isAvailable: false)
        let currentTrack = makeTrack(title: "Current", isAvailable: false)
        let tracksProvider = ControlledLibraryTracksProvider(
            responses: [[firstTrack, secondTrack, thirdTrack], [currentTrack]]
        )
        let urlProvider = ControlledTrackURLProvider()
        let viewModel = try makeViewModel(
            tracksProvider: tracksProvider,
            source: .folder(folderId: UUID()),
            trackURLProvider: urlProvider
        )
        let currentAvailabilityExpectation = expectation(
            description: "Availability current refresh применена"
        )
        let cancellable = viewModel.$trackSections
            .dropFirst()
            .sink { sections in
                guard sections.flatMap(\.tracks).first?.id == currentTrack.id,
                      sections.flatMap(\.tracks).first?.isAvailable == true else {
                    return
                }

                currentAvailabilityExpectation.fulfill()
            }

        await viewModel.refresh()
        await urlProvider.waitForRequestCount(1)
        let oldRequestedTrackIDs = await urlProvider.requestedTrackIDs()
        let firstOldRequestID = try XCTUnwrap(oldRequestedTrackIDs.first)

        await viewModel.refresh()
        await urlProvider.waitForRequestCount(2)
        await urlProvider.resumeFirst(for: firstOldRequestID, isAvailable: false)
        await Task.yield()

        await urlProvider.resumeFirst(for: currentTrack.trackId, isAvailable: true)
        await fulfillment(of: [currentAvailabilityExpectation], timeout: 1)

        let requestedTrackIDs = await urlProvider.requestedTrackIDs()
        XCTAssertEqual(Set(requestedTrackIDs), [firstOldRequestID, currentTrack.trackId])
        XCTAssertEqual(requestedTrackIDs.count, 2)
        XCTAssertFalse(viewModel.isLoading)
        withExtendedLifetime(cancellable) {}
    }

    @MainActor
    func testNormalFolderRefreshKeepsInitialListBadgesSyncAndAvailability() async throws {
        let track = makeTrack(title: "Normal", isAvailable: false)
        let tracksProvider = ControlledLibraryTracksProvider(responses: [[track]])
        let badgeProvider = LibraryBadgeProviderSpy(
            membershipsByTrackID: [
                track.trackId: [TrackListMembership(storedName: "Pinned", kind: .regular)]
            ]
        )
        let syncer = LibraryFolderSyncSpy()
        let urlProvider = ControlledTrackURLProvider(
            immediateAvailabilityByTrackID: [track.trackId: [true]]
        )
        let viewModel = try makeViewModel(
            tracksProvider: tracksProvider,
            badgeProvider: badgeProvider,
            source: .folder(folderId: UUID()),
            syncer: syncer,
            trackURLProvider: urlProvider
        )
        let availabilityExpectation = expectation(
            description: "Availability normal flow применена"
        )
        let cancellable = viewModel.$trackSections
            .dropFirst()
            .sink { sections in
                guard sections.flatMap(\.tracks).first?.isAvailable == true else {
                    return
                }

                availabilityExpectation.fulfill()
            }

        await viewModel.refresh()
        XCTAssertEqual(viewModel.trackSections.flatMap(\.tracks).map(\.id), [track.id])
        await fulfillment(of: [availabilityExpectation], timeout: 1)

        let initialLoadCount = await tracksProvider.requestCount()
        XCTAssertEqual(initialLoadCount, 1)
        XCTAssertEqual(badgeProvider.callCount, 1)
        XCTAssertEqual(syncer.folderIDs.count, 1)
        let requestedTrackIDs = await urlProvider.requestedTrackIDs()
        XCTAssertEqual(requestedTrackIDs, [track.trackId])
        XCTAssertEqual(
            viewModel.trackListMembershipsById[track.trackId]?.map(\.storedName),
            ["Pinned"]
        )
        withExtendedLifetime(cancellable) {}
    }

    @MainActor
    func testNonFolderSourceReloadsBadgesWithoutSyncOrAvailability() async throws {
        let track = makeTrack(title: "Collection", isAvailable: false)
        let tracksProvider = ControlledLibraryTracksProvider(responses: [[track]])
        let badgeProvider = LibraryBadgeProviderSpy(
            membershipsByTrackID: [
                track.trackId: [TrackListMembership(storedName: "Collection", kind: .regular)]
            ]
        )
        let syncer = LibraryFolderSyncSpy()
        let urlProvider = ControlledTrackURLProvider()
        let viewModel = try makeViewModel(
            tracksProvider: tracksProvider,
            badgeProvider: badgeProvider,
            source: .allLibraryTracks,
            syncer: syncer,
            trackURLProvider: urlProvider
        )

        await viewModel.refresh()
        await badgeProvider.waitForCallCount(1)
        await Task.yield()

        XCTAssertEqual(viewModel.trackSections.flatMap(\.tracks).first?.id, track.id)
        XCTAssertEqual(viewModel.trackSections.flatMap(\.tracks).first?.isAvailable, false)
        XCTAssertTrue(syncer.folderIDs.isEmpty)
        let requestedTrackIDs = await urlProvider.requestedTrackIDs()
        XCTAssertTrue(requestedTrackIDs.isEmpty)
    }

    @MainActor
    func testCancelledFolderSyncCannotContinueOldTaskToAvailability() async throws {
        let oldTrack = makeTrack(title: "Old sync", isAvailable: false)
        let currentTrack = makeTrack(title: "Current sync", isAvailable: false)
        let tracksProvider = ControlledLibraryTracksProvider(
            responses: [[oldTrack], [currentTrack]]
        )
        let syncer = ControlledLibraryFolderSyncer()
        let urlProvider = ControlledTrackURLProvider(
            immediateAvailabilityByTrackID: [currentTrack.trackId: [true]]
        )
        let viewModel = try makeViewModel(
            tracksProvider: tracksProvider,
            source: .folder(folderId: UUID()),
            syncer: syncer,
            trackURLProvider: urlProvider
        )
        let availabilityExpectation = expectation(
            description: "Availability после current sync применена"
        )
        let cancellable = viewModel.$trackSections
            .dropFirst()
            .sink { sections in
                guard sections.flatMap(\.tracks).first?.id == currentTrack.id,
                      sections.flatMap(\.tracks).first?.isAvailable == true else {
                    return
                }

                availabilityExpectation.fulfill()
            }

        await viewModel.refresh()
        await syncer.waitForCallCount(1)

        await viewModel.refresh()
        await syncer.waitForCallCount(2)

        syncer.completeNext()
        syncer.completeNext()
        await fulfillment(of: [availabilityExpectation], timeout: 1)

        let requestedTrackIDs = await urlProvider.requestedTrackIDs()
        XCTAssertEqual(requestedTrackIDs, [currentTrack.trackId])
        withExtendedLifetime(cancellable) {}
    }

    @MainActor
    func testBadgeEventDoesNotLaunchAdditionalBackgroundDetailsTask() async throws {
        let track = makeTrack(title: "Badges", isAvailable: false)
        let tracksProvider = ControlledLibraryTracksProvider(responses: [[track]])
        let badgeProvider = LibraryBadgeProviderSpy(
            membershipsByTrackID: [
                track.trackId: [TrackListMembership(storedName: "Events", kind: .regular)]
            ]
        )
        let eventProvider = LibraryTrackEventProviderSpy()
        let syncer = LibraryFolderSyncSpy()
        let urlProvider = ControlledTrackURLProvider()
        let viewModel = try makeViewModel(
            tracksProvider: tracksProvider,
            badgeProvider: badgeProvider,
            eventProvider: eventProvider,
            source: .allLibraryTracks,
            syncer: syncer,
            trackURLProvider: urlProvider
        )

        await viewModel.refresh()
        await badgeProvider.waitForCallCount(1)

        let badgeEventExpectation = expectation(
            description: "Badge event применён синхронным reload"
        )
        let cancellable = viewModel.$trackListMembershipsById
            .dropFirst()
            .sink { _ in
                badgeEventExpectation.fulfill()
            }

        eventProvider.sendBadgeChange()
        await fulfillment(of: [badgeEventExpectation], timeout: 1)

        XCTAssertEqual(badgeProvider.callCount, 2)
        XCTAssertTrue(syncer.folderIDs.isEmpty)
        let requestedTrackIDs = await urlProvider.requestedTrackIDs()
        XCTAssertTrue(requestedTrackIDs.isEmpty)
        withExtendedLifetime(cancellable) {}
    }

    @MainActor
    func testInitialLoadGuardAndDidLoadSemanticsAreRetained() async throws {
        let directTrack = makeTrack(title: "Direct", isAvailable: false)
        let loadedTrack = makeTrack(title: "Loaded", isAvailable: false)
        let tracksProvider = ControlledLibraryTracksProvider(
            responses: [[directTrack], [loadedTrack]],
            heldRequestNumbers: [1]
        )
        let viewModel = try makeViewModel(
            tracksProvider: tracksProvider,
            source: .allLibraryTracks,
            trackURLProvider: ControlledTrackURLProvider()
        )

        let firstRefresh = Task {
            await viewModel.refresh()
        }
        await tracksProvider.waitForRequestCount(1)

        let ignoredRefresh = Task {
            await viewModel.refresh()
        }
        await ignoredRefresh.value

        XCTAssertTrue(viewModel.isLoading)
        let heldLoadCount = await tracksProvider.requestCount()
        XCTAssertEqual(heldLoadCount, 1)

        await tracksProvider.completeNextHeldRequest()
        await firstRefresh.value

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.didLoad)

        await viewModel.loadTracksIfNeeded()
        await viewModel.loadTracksIfNeeded()

        XCTAssertTrue(viewModel.didLoad)
        let loadedRequestCount = await tracksProvider.requestCount()
        XCTAssertEqual(loadedRequestCount, 2)
    }

    /// Собирает ViewModel с реальной изолированной SQLite-базой и controlled feature dependencies.
    @MainActor
    private func makeViewModel(
        tracksProvider: any LibraryTracksProvider,
        badgeProvider: LibraryBadgeProviderSpy? = nil,
        eventProvider: LibraryTrackEventProviderSpy? = nil,
        source: LibraryTrackListSource,
        syncer: (any LibraryFolderSyncing)? = nil,
        trackURLProvider: ControlledTrackURLProvider
    ) throws -> LibraryTracksViewModel {
        let database = try makeDatabase()
        let router = LibraryBatchRouterSpy()
        let badgeProvider = badgeProvider ?? LibraryBadgeProviderSpy()
        let eventProvider = eventProvider ?? LibraryTrackEventProviderSpy()
        let syncer = syncer ?? LibraryFolderSyncSpy()

        return LibraryTracksViewModel(
            source: source,
            renameActionHandler: TrackFileRenameActionHandler(
                fileBusyChecker: LibraryTrackFileBusyCheckerSpy(),
                sheetManager: SheetManager(),
                commandExecutor: .shared,
                toastManager: ToastManager(),
                proposalBuilder: FileRenameProposalBuilder()
            ),
            tracksProvider: tracksProvider,
            badgeProvider: badgeProvider,
            eventProvider: eventProvider,
            runtimeController: LibraryTrackRuntimeController(
                runtimeSnapshotStore: LibraryRuntimeSnapshotStoreSpy(),
                runtimeSnapshotBuilder: LibraryRuntimeSnapshotBuilderSpy()
            ),
            settingsManager: LibrarySettingsManagerSpy(),
            trackRegistry: TrackRegistry(database: database),
            musicLibraryManager: syncer,
            trackURLProvider: { trackID in
                await trackURLProvider.url(for: trackID)
            },
            batchRenameHandler: LibraryBatchRenameHandler(router: router),
            batchTagEditHandler: LibraryBatchTagEditHandler(router: router),
            usesLibrarySortSettings: false
        )
    }

    /// Создаёт временную базу, чтобы первоначальная загрузка metadata не зависела от shared SQLite.
    private func makeDatabase() throws -> AppDatabase {
        let directory = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "LibraryTracksViewModelBackgroundDetailsTests-\(UUID().uuidString)",
                isDirectory: true
            )
        let database = AppDatabase(
            location: DatabaseLocation(
                databaseURL: directory.appendingPathComponent("TrackList.sqlite")
            ),
            migrator: DatabaseMigrator(migrations: DatabaseMigration.all)
        )
        try database.open()

        self.database = database
        databaseDirectory = directory
        return database
    }

    /// Создаёт физическую строку фонотеки с явно заданным row identity для stale tests.
    private func makeTrack(
        id: UUID = UUID(),
        title: String,
        isAvailable: Bool
    ) -> LibraryTrack {
        LibraryTrack(
            id: id,
            fileURL: URL(fileURLWithPath: "/tmp/\(title)-\(id.uuidString).mp3"),
            title: title,
            artist: nil,
            duration: 120,
            addedDate: Date(),
            isAvailable: isAvailable
        )
    }
}

/// Последовательно выдаёт заранее подготовленные initial списки и умеет удерживать отдельный запрос.
private actor ControlledLibraryTracksProvider: LibraryTracksProvider {

    private struct HeldRequest {
        let continuation: CheckedContinuation<[LibraryTrack], Never>
        let tracks: [LibraryTrack]
    }

    private var responses: [[LibraryTrack]]
    private let heldRequestNumbers: Set<Int>
    private var requestedCount = 0
    private var heldRequests: [HeldRequest] = []
    private var requestCountWaiters: [CheckedContinuation<Void, Never>] = []

    init(
        responses: [[LibraryTrack]],
        heldRequestNumbers: Set<Int> = []
    ) {
        self.responses = responses
        self.heldRequestNumbers = heldRequestNumbers
    }

    func tracks(for source: LibraryTrackListSource) async -> [LibraryTrack] {
        requestedCount += 1
        let tracks = responses.isEmpty ? [] : responses.removeFirst()
        notifyRequestCountWaiters()

        guard heldRequestNumbers.contains(requestedCount) else {
            return tracks
        }

        return await withCheckedContinuation { continuation in
            heldRequests.append(HeldRequest(continuation: continuation, tracks: tracks))
        }
    }

    func requestCount() -> Int {
        requestedCount
    }

    func waitForRequestCount(_ expectedCount: Int) async {
        while requestedCount < expectedCount {
            await withCheckedContinuation { continuation in
                requestCountWaiters.append(continuation)
            }
        }
    }

    func completeNextHeldRequest() {
        guard heldRequests.isEmpty == false else {
            return
        }

        let request = heldRequests.removeFirst()
        request.continuation.resume(returning: request.tracks)
    }

    private func notifyRequestCountWaiters() {
        let waiters = requestCountWaiters
        requestCountWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }
}

/// Контролирует completion URL-запросов и фиксирует cooperative cancellation фоновой задачи.
private actor ControlledTrackURLProvider {

    private struct PendingRequest {
        let trackID: UUID
        let continuation: CheckedContinuation<URL?, Never>
    }

    private var immediateAvailabilityByTrackID: [UUID: [Bool]]
    private var requestedIDs: [UUID] = []
    private var pendingRequests: [PendingRequest] = []
    private var returnedCancellationStatuses: [UUID: [Bool]] = [:]
    private var requestCountWaiters: [CheckedContinuation<Void, Never>] = []
    private var returnCountWaiters: [CheckedContinuation<Void, Never>] = []

    init(immediateAvailabilityByTrackID: [UUID: [Bool]] = [:]) {
        self.immediateAvailabilityByTrackID = immediateAvailabilityByTrackID
    }

    func url(for trackID: UUID) async -> URL? {
        requestedIDs.append(trackID)
        notifyRequestCountWaiters()

        if var availability = immediateAvailabilityByTrackID[trackID],
           availability.isEmpty == false {
            let isAvailable = availability.removeFirst()
            immediateAvailabilityByTrackID[trackID] = availability
            return isAvailable ? URL(fileURLWithPath: "/tmp/\(trackID.uuidString).mp3") : nil
        }

        let result = await withCheckedContinuation { continuation in
            pendingRequests.append(
                PendingRequest(trackID: trackID, continuation: continuation)
            )
        }

        // Проверка после controlled continuation доказывает, что старый caller уже отменён.
        returnedCancellationStatuses[trackID, default: []].append(Task.isCancelled)
        notifyReturnCountWaiters()
        return result
    }

    func requestedTrackIDs() -> [UUID] {
        requestedIDs
    }

    func cancellationStatuses(for trackID: UUID) -> [Bool] {
        returnedCancellationStatuses[trackID, default: []]
    }

    func waitForRequestCount(_ expectedCount: Int) async {
        while requestedIDs.count < expectedCount {
            await withCheckedContinuation { continuation in
                requestCountWaiters.append(continuation)
            }
        }
    }

    func waitForReturnCount(_ expectedCount: Int) async {
        while returnedCancellationStatuses.values.reduce(0, { $0 + $1.count }) < expectedCount {
            await withCheckedContinuation { continuation in
                returnCountWaiters.append(continuation)
            }
        }
    }

    func resumeFirst(for trackID: UUID, isAvailable: Bool) {
        resumePendingRequest(
            at: pendingRequests.firstIndex { $0.trackID == trackID },
            isAvailable: isAvailable
        )
    }

    func resumeLast(for trackID: UUID, isAvailable: Bool) {
        resumePendingRequest(
            at: pendingRequests.lastIndex { $0.trackID == trackID },
            isAvailable: isAvailable
        )
    }

    private func resumePendingRequest(at index: Int?, isAvailable: Bool) {
        guard let index else {
            return
        }

        let request = pendingRequests.remove(at: index)
        let url = isAvailable
            ? URL(fileURLWithPath: "/tmp/\(request.trackID.uuidString).mp3")
            : nil
        request.continuation.resume(returning: url)
    }

    private func notifyRequestCountWaiters() {
        let waiters = requestCountWaiters
        requestCountWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    private func notifyReturnCountWaiters() {
        let waiters = returnCountWaiters
        returnCountWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }
}

/// Считает manager-level sync без изменения её per-root production semantics.
@MainActor
private final class LibraryFolderSyncSpy: LibraryFolderSyncing {
    private(set) var folderIDs: [UUID] = []

    func syncFolderIfNeeded(folderId: UUID) async throws -> LibrarySyncOutcome {
        folderIDs.append(folderId)
        return .confirmed(
            LibrarySyncReceipt(
                rootFolderId: folderId,
                scannedFileCount: 1,
                insertedTrackCount: 0,
                updatedTrackCount: 1,
                removedTrackCount: 0,
                tracks: []
            )
        )
    }
}

/// Удерживает sync completion, чтобы проверить stale guard после nonthrowing manager contract.
@MainActor
private final class ControlledLibraryFolderSyncer: LibraryFolderSyncing {
    private var pendingContinuations: [CheckedContinuation<LibrarySyncOutcome, Never>] = []
    private var calls = 0
    private var callCountWaiters: [CheckedContinuation<Void, Never>] = []

    func syncFolderIfNeeded(folderId: UUID) async throws -> LibrarySyncOutcome {
        calls += 1
        notifyCallCountWaiters()

        return await withCheckedContinuation { continuation in
            pendingContinuations.append(continuation)
        }
    }

    func waitForCallCount(_ expectedCount: Int) async {
        while calls < expectedCount {
            await withCheckedContinuation { continuation in
                callCountWaiters.append(continuation)
            }
        }
    }

    func completeNext() {
        guard pendingContinuations.isEmpty == false else {
            return
        }

        pendingContinuations.removeFirst().resume(
            returning: .skipped(.emptyScanProtected)
        )
    }

    private func notifyCallCountWaiters() {
        let waiters = callCountWaiters
        callCountWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }
}

/// Возвращает предсказуемые badges и позволяет ожидать завершения synchronous reload.
private final class LibraryBadgeProviderSpy: TrackListBadgeProvider {
    private let membershipsByTrackID: [UUID: [TrackListMembership]]
    private(set) var callCount = 0
    private var callCountWaiters: [CheckedContinuation<Void, Never>] = []

    init(membershipsByTrackID: [UUID: [TrackListMembership]] = [:]) {
        self.membershipsByTrackID = membershipsByTrackID
    }

    func badges(for trackIds: [UUID]) -> [UUID: [TrackListMembership]] {
        callCount += 1

        let waiters = callCountWaiters
        callCountWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }

        return membershipsByTrackID.filter { trackIds.contains($0.key) }
    }

    func waitForCallCount(_ expectedCount: Int) async {
        while callCount < expectedCount {
            await withCheckedContinuation { continuation in
                callCountWaiters.append(continuation)
            }
        }
    }
}

/// Изолирует ViewModel от внешнего NotificationCenter и позволяет явно послать badge event.
@MainActor
private final class LibraryTrackEventProviderSpy: LibraryTrackEventProvider {
    private let badgeChanges = PassthroughSubject<Void, Never>()

    var trackDidUpdate: AnyPublisher<TrackUpdateEvent, Never> {
        Empty().eraseToAnyPublisher()
    }

    var trackBatchDidUpdate: AnyPublisher<[TrackUpdateEvent], Never> {
        Empty().eraseToAnyPublisher()
    }

    var libraryDataDidChange: AnyPublisher<Void, Never> {
        Empty().eraseToAnyPublisher()
    }

    var appSettingsDidChange: AnyPublisher<Void, Never> {
        Empty().eraseToAnyPublisher()
    }

    var trackListBadgesDidChange: AnyPublisher<Void, Never> {
        badgeChanges.eraseToAnyPublisher()
    }

    func sendBadgeChange() {
        badgeChanges.send()
    }
}

/// Предоставляет неизменяемые presentation settings для проверки lifecycle без persistent настроек.
@MainActor
private final class LibrarySettingsManagerSpy: SettingsManaging {
    @Published private var currentSettings = AppSettings.defaultValue

    var settings: AppSettings { currentSettings }
    var settingsPublisher: Published<AppSettings>.Publisher { $currentSettings }

    func setTagReadingEnabled(_: Bool) {}
    func setTrackListMembershipVisible(_: Bool) {}
    func setFileFormatVisible(_: Bool) {}
    func setPurchasedITunesSourceVisible(_: Bool) {}
    func setMiniPlayerExpanded(_: Bool) {}
    func setLibraryRootDisplayMode(_: LibraryRootDisplayMode) throws {}
    func setLibraryTrackSortMode(_: LibraryTrackSortMode) throws {}
    func setTrackListsSortMode(_: TrackListsSortMode?) throws {}
    func applyPersistedTrackListsSortMode(_: TrackListsSortMode?) {}
}

/// Не участвует в details tests, но сохраняет ViewModel на production-подобном runtime controller graph.
@MainActor
private final class LibraryRuntimeSnapshotStoreSpy: TrackRuntimeSnapshotStoring {
    func snapshot(forTrackId trackId: UUID) -> TrackRuntimeSnapshot? {
        nil
    }

    func storeSnapshot(_ snapshot: TrackRuntimeSnapshot) {}
}

/// Не строит runtime metadata, потому что сценарии проверяют только lifecycle screen details.
private struct LibraryRuntimeSnapshotBuilderSpy: TrackRuntimeSnapshotBuilding {
    func buildSnapshot(forTrackId trackId: UUID) async throws -> TrackRuntimeSnapshot? {
        nil
    }
}

/// Закрывает неиспользуемые batch dependencies без создания SheetManager в XCTest.
@MainActor
private final class LibraryBatchRouterSpy: BatchFilenameRenameRouting, BatchTagEditRouting {
    func presentBatchFilenameRename(
        pendingAction: PendingBulkTrackAction,
        tracks: [BatchFilenameRenameTrackSeed]
    ) {}

    func dismissBatchFilenameRename(_ routeID: UUID) {}

    func presentBatchTagEdit(pendingAction: PendingBulkTrackAction) {}

    func dismissBatchTagEdit(_ routeID: UUID) {}
}

/// Не сообщает о занятом файле, потому что rename handler не участвует в lifecycle details tests.
@MainActor
private final class LibraryTrackFileBusyCheckerSpy: TrackFileBusyChecking {
    func isTrackFileBusy(trackId: UUID) -> Bool {
        false
    }
}
