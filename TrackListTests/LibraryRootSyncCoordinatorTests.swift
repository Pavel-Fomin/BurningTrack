//
//  LibraryRootSyncCoordinatorTests.swift
//  TrackList
//
//  Controlled XCTest для per-root ownership синхронизации фонотеки.
//
//  Created by Pavel Fomin on 21.08.2026.
//

import Foundation
import XCTest
@testable import TrackList

@MainActor
final class LibraryRootSyncCoordinatorTests: XCTestCase {

    func testSameRootStartsSecondScanOnlyAfterFirstOperationCompletes() async {
        let coordinator = LibraryRootSyncCoordinator()
        let scanner = ControlledLibraryScanner()
        let rootFolderID = UUID()

        let first = syncTask(coordinator: coordinator, rootFolderID: rootFolderID) {
            _ = try await scanner.scan(rootFolderID: rootFolderID)
        }
        await scanner.waitForInvocationCount(1, for: rootFolderID)

        let second = syncTask(coordinator: coordinator, rootFolderID: rootFolderID) {
            _ = try await scanner.scan(rootFolderID: rootFolderID)
        }
        await Task.yield()

        let invocationCountBeforeFirstCompletion = await scanner.invocationCount(for: rootFolderID)
        XCTAssertEqual(invocationCountBeforeFirstCompletion, 1)

        await scanner.completeNext(for: rootFolderID)
        _ = await first.value

        await scanner.waitForInvocationCount(2, for: rootFolderID)
        await scanner.completeNext(for: rootFolderID)
        _ = await second.value

        let invocationCount = await scanner.invocationCount(for: rootFolderID)
        XCTAssertEqual(invocationCount, 2)
    }

    func testDifferentRootsCanStartScansInParallel() async {
        let coordinator = LibraryRootSyncCoordinator()
        let scanner = ControlledLibraryScanner()
        let firstRootFolderID = UUID()
        let secondRootFolderID = UUID()

        let first = syncTask(coordinator: coordinator, rootFolderID: firstRootFolderID) {
            _ = try await scanner.scan(rootFolderID: firstRootFolderID)
        }
        let second = syncTask(coordinator: coordinator, rootFolderID: secondRootFolderID) {
            _ = try await scanner.scan(rootFolderID: secondRootFolderID)
        }

        await scanner.waitForInvocationCount(1, for: firstRootFolderID)
        await scanner.waitForInvocationCount(1, for: secondRootFolderID)

        let firstRootInvocations = await scanner.invocationCount(for: firstRootFolderID)
        let secondRootInvocations = await scanner.invocationCount(for: secondRootFolderID)
        XCTAssertEqual(firstRootInvocations, 1)
        XCTAssertEqual(secondRootInvocations, 1)

        await scanner.completeNext(for: firstRootFolderID)
        await scanner.completeNext(for: secondRootFolderID)
        _ = await first.value
        _ = await second.value
    }

    func testOldFullOperationCannotDeleteNewerSafeOperationState() async {
        let coordinator = LibraryRootSyncCoordinator()
        let scanner = ControlledLibraryScanner()
        let state = SimulatedLibraryState(initialPaths: ["Old.mp3", "Missing.mp3"])
        let rootFolderID = UUID()

        await scanner.setFilesystemSnapshot(
            ScanSnapshot(filePaths: ["Old.mp3"]),
            for: rootFolderID
        )
        let oldFull = syncTask(coordinator: coordinator, rootFolderID: rootFolderID) {
            let snapshot = try await scanner.scan(rootFolderID: rootFolderID)
            await state.apply(snapshot: snapshot, mode: .full)
        }
        await scanner.waitForInvocationCount(1, for: rootFolderID)

        let newerSafe = syncTask(coordinator: coordinator, rootFolderID: rootFolderID) {
            let snapshot = try await scanner.scan(rootFolderID: rootFolderID)
            await state.apply(snapshot: snapshot, mode: .safe)
        }
        await Task.yield()

        await scanner.setFilesystemSnapshot(
            ScanSnapshot(filePaths: ["Old.mp3", "New.mp3"]),
            for: rootFolderID
        )
        await scanner.completeNext(for: rootFolderID)
        _ = await oldFull.value

        await scanner.waitForInvocationCount(2, for: rootFolderID)
        await scanner.completeNext(for: rootFolderID)
        _ = await newerSafe.value

        let stateAfterBothOperations = await state.snapshot()
        XCTAssertTrue(stateAfterBothOperations.trackPaths.contains("New.mp3"))
        XCTAssertTrue(stateAfterBothOperations.bookmarkPaths.contains("New.mp3"))
        XCTAssertTrue(stateAfterBothOperations.identityPaths.contains("New.mp3"))
    }

    func testQueuedRequestScansFilesystemOnlyAfterItReceivesRootOwnership() async {
        let coordinator = LibraryRootSyncCoordinator()
        let scanner = ControlledLibraryScanner()
        let observedSnapshots = ObservedSnapshots()
        let rootFolderID = UUID()

        await scanner.setFilesystemSnapshot(
            ScanSnapshot(filePaths: ["Before.mp3"]),
            for: rootFolderID
        )
        let first = syncTask(coordinator: coordinator, rootFolderID: rootFolderID) {
            _ = try await scanner.scan(rootFolderID: rootFolderID)
        }
        await scanner.waitForInvocationCount(1, for: rootFolderID)

        let second = syncTask(coordinator: coordinator, rootFolderID: rootFolderID) {
            let snapshot = try await scanner.scan(rootFolderID: rootFolderID)
            await observedSnapshots.record(snapshot)
        }
        await Task.yield()

        await scanner.setFilesystemSnapshot(
            ScanSnapshot(filePaths: ["After.mp3"]),
            for: rootFolderID
        )
        await scanner.completeNext(for: rootFolderID)
        _ = await first.value

        await scanner.waitForInvocationCount(2, for: rootFolderID)
        await scanner.completeNext(for: rootFolderID)
        _ = await second.value

        let snapshots = await observedSnapshots.values()
        XCTAssertEqual(snapshots, [ScanSnapshot(filePaths: ["After.mp3"])])
    }

    func testFailureReleasesRootForNextRequest() async {
        let coordinator = LibraryRootSyncCoordinator()
        let scanner = ControlledLibraryScanner()
        let rootFolderID = UUID()

        let first = syncTask(coordinator: coordinator, rootFolderID: rootFolderID) {
            _ = try await scanner.scan(rootFolderID: rootFolderID)
        }
        await scanner.waitForInvocationCount(1, for: rootFolderID)

        let second = syncTask(coordinator: coordinator, rootFolderID: rootFolderID) {
            _ = try await scanner.scan(rootFolderID: rootFolderID)
        }
        await Task.yield()

        await scanner.completeNext(for: rootFolderID, error: ControlledScannerError.expectedFailure)
        let firstResult = await first.value
        XCTAssertTrue(firstResult.isFailure(ControlledScannerError.expectedFailure))

        await scanner.waitForInvocationCount(2, for: rootFolderID)
        await scanner.completeNext(for: rootFolderID)
        let secondResult = await second.value
        XCTAssertTrue(secondResult.isSuccess)
    }

    func testCancelledQueuedRequestSkipsScanAndDoesNotBlockFollowingRequest() async {
        let coordinator = LibraryRootSyncCoordinator()
        let scanner = ControlledLibraryScanner()
        let startedOperations = StartedOperations()
        let rootFolderID = UUID()

        let first = syncTask(coordinator: coordinator, rootFolderID: rootFolderID) {
            await startedOperations.record("A")
            _ = try await scanner.scan(rootFolderID: rootFolderID)
        }
        await scanner.waitForInvocationCount(1, for: rootFolderID)

        let cancelledSecond = syncTask(coordinator: coordinator, rootFolderID: rootFolderID) {
            await startedOperations.record("B")
            _ = try await scanner.scan(rootFolderID: rootFolderID)
        }
        await Task.yield()

        let third = syncTask(coordinator: coordinator, rootFolderID: rootFolderID) {
            await startedOperations.record("C")
            _ = try await scanner.scan(rootFolderID: rootFolderID)
        }
        await Task.yield()
        cancelledSecond.cancel()

        await scanner.completeNext(for: rootFolderID)
        _ = await first.value

        await scanner.waitForInvocationCount(2, for: rootFolderID)
        let started = await startedOperations.values()
        XCTAssertEqual(started, ["A", "C"])

        await scanner.completeNext(for: rootFolderID)
        let cancelledResult = await cancelledSecond.value
        let thirdResult = await third.value
        XCTAssertTrue(cancelledResult.isCancellation)
        XCTAssertTrue(thirdResult.isSuccess)
    }

    func testSafeAndFullKeepTheirExistingDeletionSemantics() {
        let presentID = UUID()
        let missingID = UUID()
        let existing = [
            makeTrackEntry(id: presentID, path: "Present.mp3"),
            makeTrackEntry(id: missingID, path: "Missing.mp3")
        ]

        let safeDeletions = LibrarySyncReconciliation.entriesToDelete(
            existing: existing,
            aliveIDs: [presentID],
            mode: .safe
        )
        let fullDeletions = LibrarySyncReconciliation.entriesToDelete(
            existing: existing,
            aliveIDs: [presentID],
            mode: .full
        )

        XCTAssertTrue(safeDeletions.isEmpty)
        XCTAssertEqual(fullDeletions.map(\.id), [missingID])
    }

    func testEmptyScanDoesNotApplyFullReconciliation() async {
        let state = SimulatedLibraryState(initialPaths: ["Existing.mp3"])
        let emptySnapshot = ScanSnapshot(filePaths: [])

        if LibrarySyncReconciliation.shouldApply(scannedFileCount: 0) {
            await state.apply(snapshot: emptySnapshot, mode: .full)
        }

        let stateAfterEmptyScan = await state.snapshot()
        XCTAssertTrue(stateAfterEmptyScan.trackPaths.contains("Existing.mp3"))
        XCTAssertTrue(stateAfterEmptyScan.bookmarkPaths.contains("Existing.mp3"))
        XCTAssertTrue(stateAfterEmptyScan.identityPaths.contains("Existing.mp3"))
    }

    func testOnlyCompletedNonEmptyOperationsEmitFinalDataChange() async {
        let coordinator = LibraryRootSyncCoordinator()
        let scanner = ControlledLibraryScanner()
        let completionRecorder = SyncCompletionRecorder()
        let rootFolderID = UUID()

        await scanner.setFilesystemSnapshot(
            ScanSnapshot(filePaths: ["Completed.mp3"]),
            for: rootFolderID
        )
        let completed = syncTask(coordinator: coordinator, rootFolderID: rootFolderID) {
            let snapshot = try await scanner.scan(rootFolderID: rootFolderID)
            guard LibrarySyncReconciliation.shouldApply(scannedFileCount: snapshot.filePaths.count) else {
                return
            }

            await completionRecorder.recordFinalDataChange()
        }
        await scanner.waitForInvocationCount(1, for: rootFolderID)
        await scanner.completeNext(for: rootFolderID)
        _ = await completed.value

        await scanner.setFilesystemSnapshot(ScanSnapshot(filePaths: []), for: rootFolderID)
        let empty = syncTask(coordinator: coordinator, rootFolderID: rootFolderID) {
            let snapshot = try await scanner.scan(rootFolderID: rootFolderID)
            guard LibrarySyncReconciliation.shouldApply(scannedFileCount: snapshot.filePaths.count) else {
                return
            }

            await completionRecorder.recordFinalDataChange()
        }
        await scanner.waitForInvocationCount(2, for: rootFolderID)
        await scanner.completeNext(for: rootFolderID)
        _ = await empty.value

        let finalDataChangeCount = await completionRecorder.finalDataChangeCount()
        XCTAssertEqual(finalDataChangeCount, 1)
    }

    private func syncTask(
        coordinator: LibraryRootSyncCoordinator,
        rootFolderID: UUID,
        operation: @escaping @Sendable () async throws -> Void
    ) -> Task<SyncTaskResult, Never> {
        Task {
            do {
                try await coordinator.run(rootFolderId: rootFolderID, operation: operation)
                return .success
            } catch is CancellationError {
                return .cancelled
            } catch let error as ControlledScannerError {
                return .failure(error)
            } catch {
                return .unexpectedFailure
            }
        }
    }

    private func makeTrackEntry(id: UUID, path: String) -> TrackRegistry.TrackEntry {
        TrackRegistry.TrackEntry(
            id: id,
            fileName: path,
            relativePath: path,
            folderId: UUID(),
            rootFolderId: UUID(),
            importedAt: Date(),
            fileDate: Date(),
            updatedAt: Date()
        )
    }
}

private enum SyncTaskResult: Equatable {
    case success
    case cancelled
    case failure(ControlledScannerError)
    case unexpectedFailure

    var isSuccess: Bool {
        self == .success
    }

    var isCancellation: Bool {
        self == .cancelled
    }

    func isFailure(_ expectedError: ControlledScannerError) -> Bool {
        self == .failure(expectedError)
    }
}

private enum ControlledScannerError: Error, Equatable {
    case expectedFailure
}

private struct ScanSnapshot: Equatable {
    let filePaths: Set<String>
}

private actor ControlledLibraryScanner {
    private struct PendingScan {
        let snapshot: ScanSnapshot
        let continuation: CheckedContinuation<ScanSnapshot, Error>
    }

    private struct InvocationWaiter {
        let rootFolderID: UUID
        let requiredCount: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private var filesystemSnapshots: [UUID: ScanSnapshot] = [:]
    private var pendingScans: [UUID: [PendingScan]] = [:]
    private var invocationCounts: [UUID: Int] = [:]
    private var invocationWaiters: [InvocationWaiter] = []

    /// Снимок читается при старте scan, поэтому queued request не может заранее
    /// запомнить файловое состояние, пока другой request владеет тем же root.
    func scan(rootFolderID: UUID) async throws -> ScanSnapshot {
        let snapshot = filesystemSnapshots[rootFolderID] ?? ScanSnapshot(filePaths: [])

        return try await withCheckedThrowingContinuation { continuation in
            invocationCounts[rootFolderID, default: 0] += 1
            pendingScans[rootFolderID, default: []].append(
                PendingScan(snapshot: snapshot, continuation: continuation)
            )
            resumeInvocationWaitersIfNeeded()
        }
    }

    func setFilesystemSnapshot(_ snapshot: ScanSnapshot, for rootFolderID: UUID) {
        filesystemSnapshots[rootFolderID] = snapshot
    }

    func waitForInvocationCount(_ requiredCount: Int, for rootFolderID: UUID) async {
        guard invocationCounts[rootFolderID, default: 0] < requiredCount else {
            return
        }

        await withCheckedContinuation { continuation in
            invocationWaiters.append(
                InvocationWaiter(
                    rootFolderID: rootFolderID,
                    requiredCount: requiredCount,
                    continuation: continuation
                )
            )
        }
    }

    func completeNext(for rootFolderID: UUID, error: Error? = nil) {
        guard var pending = pendingScans[rootFolderID], pending.isEmpty == false else {
            XCTFail("Не найден удержанный scan для root \(rootFolderID)")
            return
        }

        let next = pending.removeFirst()
        pendingScans[rootFolderID] = pending.isEmpty ? nil : pending

        if let error {
            next.continuation.resume(throwing: error)
        } else {
            next.continuation.resume(returning: next.snapshot)
        }
    }

    func invocationCount(for rootFolderID: UUID) -> Int {
        invocationCounts[rootFolderID, default: 0]
    }

    private func resumeInvocationWaitersIfNeeded() {
        var remainingWaiters: [InvocationWaiter] = []

        for waiter in invocationWaiters {
            if invocationCounts[waiter.rootFolderID, default: 0] >= waiter.requiredCount {
                waiter.continuation.resume()
            } else {
                remainingWaiters.append(waiter)
            }
        }

        invocationWaiters = remainingWaiters
    }
}

private actor SimulatedLibraryState {
    struct Snapshot {
        let trackPaths: Set<String>
        let bookmarkPaths: Set<String>
        let identityPaths: Set<String>
    }

    private var trackPaths: Set<String>
    private var bookmarkPaths: Set<String>
    private var identityPaths: Set<String>

    init(initialPaths: Set<String>) {
        trackPaths = initialPaths
        bookmarkPaths = initialPaths
        identityPaths = initialPaths
    }

    /// Модель трёх связанных реестров нужна только для проверки порядка операций;
    /// реальная пользовательская SQLite-база в concurrency-тестах не используется.
    func apply(snapshot: ScanSnapshot, mode: LibrarySyncModule.SyncMode) {
        trackPaths.formUnion(snapshot.filePaths)
        bookmarkPaths.formUnion(snapshot.filePaths)
        identityPaths.formUnion(snapshot.filePaths)

        guard case .full = mode else {
            return
        }

        let removedPaths = trackPaths.subtracting(snapshot.filePaths)
        trackPaths.subtract(removedPaths)
        bookmarkPaths.subtract(removedPaths)
        identityPaths.subtract(removedPaths)
    }

    func snapshot() -> Snapshot {
        Snapshot(
            trackPaths: trackPaths,
            bookmarkPaths: bookmarkPaths,
            identityPaths: identityPaths
        )
    }
}

private actor ObservedSnapshots {
    private var snapshots: [ScanSnapshot] = []

    func record(_ snapshot: ScanSnapshot) {
        snapshots.append(snapshot)
    }

    func values() -> [ScanSnapshot] {
        snapshots
    }
}

private actor StartedOperations {
    private var operations: [String] = []

    func record(_ operation: String) {
        operations.append(operation)
    }

    func values() -> [String] {
        operations
    }
}

private actor SyncCompletionRecorder {
    private var count = 0

    func recordFinalDataChange() {
        count += 1
    }

    func finalDataChangeCount() -> Int {
        count
    }
}
