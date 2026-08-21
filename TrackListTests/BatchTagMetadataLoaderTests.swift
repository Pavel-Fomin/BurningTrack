//
//  BatchTagMetadataLoaderTests.swift
//  TrackList
//
//  Проверяет cancellation и limiter-границы загрузки metadata для Batch Tag.
//
//  Created by Pavel Fomin on 21.08.2026.
//

import Foundation
import XCTest
@testable import TrackList

@MainActor
final class BatchTagMetadataLoaderTests: XCTestCase {

    func testParentCancellationDoesNotStartQueuedMetadataJobsAfterFirstSlotIsReleased() async {
        let trackIDs = [UUID(), UUID(), UUID()]
        let pipeline = BlockingBatchTagSnapshotPipeline(
            snapshots: Dictionary(uniqueKeysWithValues: trackIDs.map {
                ($0, makeSnapshot(trackID: $0, title: $0.uuidString))
            })
        )
        let loader = BatchTagMetadataLoader(
            concurrentLimit: 1,
            snapshotLoadingOperation: { trackID in
                await pipeline.loadSnapshot(for: trackID)
            }
        )
        let pendingAction = PendingBulkTrackAction(action: .editTags, trackIDs: trackIDs)

        let loadingTask = Task {
            await loader.loadFlow(pendingAction: pendingAction)
        }
        await pipeline.waitForStartedCount(1)
        await pipeline.waitForHeldCount(1)

        loadingTask.cancel()
        let resumedFirstBuild = await pipeline.resumeNext()
        XCTAssertTrue(resumedFirstBuild)

        let cancelledFlow = await loadingTask.value
        let startedTrackIDs = await pipeline.startedTrackIDs

        XCTAssertEqual(startedTrackIDs.count, 1)
        XCTAssertTrue(cancelledFlow.tracks.isEmpty)
    }

    func testNormalLoadingReusesStoredSnapshotsBuildsMissingSnapshotsAndPreservesSelectionOrder() async {
        let storedTrackID = UUID()
        let builtTrackID = UUID()
        let storedSnapshot = makeSnapshot(trackID: storedTrackID, title: "Stored")
        let builtSnapshot = makeSnapshot(trackID: builtTrackID, title: "Built")
        let pipeline = BatchTagSnapshotPipeline(
            storedSnapshots: [storedTrackID: storedSnapshot],
            builtSnapshots: [builtTrackID: builtSnapshot]
        )
        let loader = BatchTagMetadataLoader(
            concurrentLimit: 2,
            snapshotLoadingOperation: { trackID in
                await pipeline.loadSnapshot(for: trackID)
            }
        )
        let pendingAction = PendingBulkTrackAction(
            action: .editTags,
            trackIDs: [builtTrackID, storedTrackID]
        )

        let flow = await loader.loadFlow(pendingAction: pendingAction)
        let reusedTrackIDs = await pipeline.reusedTrackIDs
        let builtTrackIDs = await pipeline.builtTrackIDs
        let storedAfterBuildTrackIDs = await pipeline.storedAfterBuildTrackIDs

        XCTAssertEqual(reusedTrackIDs, [storedTrackID])
        XCTAssertEqual(builtTrackIDs, [builtTrackID])
        XCTAssertEqual(storedAfterBuildTrackIDs, [builtTrackID])
        XCTAssertEqual(flow.tracks.map(\.trackId), [builtTrackID, storedTrackID])
    }

    func testBuilderFailureKeepsAvailableTracksAndReturnsCapacityToLaterLoad() async {
        let failedTrackID = UUID()
        let availableTrackID = UUID()
        let followUpTrackID = UUID()
        let availableSnapshot = makeSnapshot(trackID: availableTrackID, title: "Available")
        let followUpSnapshot = makeSnapshot(trackID: followUpTrackID, title: "Follow up")
        let pipeline = BatchTagSnapshotPipeline(
            storedSnapshots: [:],
            builtSnapshots: [
                availableTrackID: availableSnapshot,
                followUpTrackID: followUpSnapshot
            ],
            failedTrackIDs: [failedTrackID]
        )
        let loader = BatchTagMetadataLoader(
            concurrentLimit: 1,
            snapshotLoadingOperation: { trackID in
                await pipeline.loadSnapshot(for: trackID)
            }
        )

        let firstFlow = await loader.loadFlow(
            pendingAction: PendingBulkTrackAction(
                action: .editTags,
                trackIDs: [failedTrackID, availableTrackID]
            )
        )
        let followUpFlow = await loader.loadFlow(
            pendingAction: PendingBulkTrackAction(
                action: .editTags,
                trackIDs: [followUpTrackID]
            )
        )

        XCTAssertEqual(firstFlow.tracks.map(\.trackId), [availableTrackID])
        XCTAssertEqual(followUpFlow.tracks.map(\.trackId), [followUpTrackID])
    }

    func testNonPositiveConcurrentLimitUsesOneWorkingSlotInsteadOfWaitingForever() async {
        let trackID = UUID()
        let snapshot = makeSnapshot(trackID: trackID, title: "Normalized")
        let pipeline = BatchTagSnapshotPipeline(
            storedSnapshots: [:],
            builtSnapshots: [trackID: snapshot]
        )
        let loader = BatchTagMetadataLoader(
            concurrentLimit: 0,
            snapshotLoadingOperation: { requestedTrackID in
                await pipeline.loadSnapshot(for: requestedTrackID)
            }
        )

        let flow = await loader.loadFlow(
            pendingAction: PendingBulkTrackAction(action: .editTags, trackIDs: [trackID])
        )

        XCTAssertEqual(flow.tracks.map(\.trackId), [trackID])
        let builtTrackIDs = await pipeline.builtTrackIDs
        XCTAssertEqual(builtTrackIDs, [trackID])
    }

    /// Проверяет созданные TaskGroup child tasks на 1–500 треках, отделяя их число от реальной тяжёлой параллельности.
    func testBatchSizesReturnAllSnapshotsWithoutExceedingConfiguredConcurrency() async {
        let limit = 6

        for count in [1, 10, 100, 300, 500] {
            let trackIDs = (0..<count).map { _ in UUID() }
            let snapshots = Dictionary(uniqueKeysWithValues: trackIDs.map {
                ($0, makeSnapshot(trackID: $0, title: $0.uuidString))
            })
            let pipeline = BoundedBatchTagSnapshotPipeline(snapshots: snapshots)
            let loader = BatchTagMetadataLoader(
                concurrentLimit: limit,
                snapshotLoadingOperation: { trackID in
                    await pipeline.loadSnapshot(for: trackID)
                }
            )
            let pendingAction = PendingBulkTrackAction(
                action: .editTags,
                trackIDs: trackIDs
            )

            let loadingTask = Task {
                await loader.loadFlow(pendingAction: pendingAction)
            }
            let expectedConcurrency = min(count, limit)
            await pipeline.waitForStartedCount(expectedConcurrency)
            await pipeline.waitForHeldCount(expectedConcurrency)
            let maximumConcurrency = await pipeline.maximumConcurrency

            XCTAssertEqual(maximumConcurrency, expectedConcurrency, "count=\(count)")

            await pipeline.openAndResumeAll()
            let flow = await loadingTask.value
            let startedCount = await pipeline.startedCount

            XCTAssertEqual(startedCount, count, "count=\(count)")
            XCTAssertEqual(flow.tracks.map(\.trackId), trackIDs, "count=\(count)")
        }
    }
}

/// Имитирует store и builder без файловой системы, сохраняя их наблюдаемый контракт для loader-а.
private actor BatchTagSnapshotPipeline {
    private var storedSnapshots: [UUID: TrackRuntimeSnapshot]
    private let builtSnapshots: [UUID: TrackRuntimeSnapshot]
    private let failedTrackIDs: Set<UUID>
    private(set) var reusedTrackIDs: [UUID] = []
    private(set) var builtTrackIDs: [UUID] = []
    private(set) var storedAfterBuildTrackIDs: [UUID] = []

    init(
        storedSnapshots: [UUID: TrackRuntimeSnapshot],
        builtSnapshots: [UUID: TrackRuntimeSnapshot],
        failedTrackIDs: Set<UUID> = []
    ) {
        self.storedSnapshots = storedSnapshots
        self.builtSnapshots = builtSnapshots
        self.failedTrackIDs = failedTrackIDs
    }

    func loadSnapshot(for trackID: UUID) -> TrackRuntimeSnapshot? {
        if let storedSnapshot = storedSnapshots[trackID] {
            reusedTrackIDs.append(trackID)
            return storedSnapshot
        }

        builtTrackIDs.append(trackID)
        guard !failedTrackIDs.contains(trackID),
              let builtSnapshot = builtSnapshots[trackID] else {
            return nil
        }

        storedSnapshots[trackID] = builtSnapshot
        storedAfterBuildTrackIDs.append(trackID)
        return builtSnapshot
    }
}

/// Удерживает первую metadata operation, чтобы parent cancellation можно было разрешить детерминированно.
private actor BlockingBatchTagSnapshotPipeline {
    private let snapshots: [UUID: TrackRuntimeSnapshot]
    private var started: [UUID] = []
    private var heldContinuations: [CheckedContinuation<Void, Never>] = []
    private var startWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var heldWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    var startedTrackIDs: [UUID] {
        started
    }

    init(snapshots: [UUID: TrackRuntimeSnapshot]) {
        self.snapshots = snapshots
    }

    func loadSnapshot(for trackID: UUID) async -> TrackRuntimeSnapshot? {
        started.append(trackID)
        resumeStartWaitersIfNeeded()

        await withCheckedContinuation { continuation in
            heldContinuations.append(continuation)
            resumeHeldWaitersIfNeeded()
        }

        return snapshots[trackID]
    }

    func waitForStartedCount(_ count: Int) async {
        guard started.count < count else { return }

        await withCheckedContinuation { continuation in
            startWaiters.append((count, continuation))
        }
    }

    func waitForHeldCount(_ count: Int) async {
        guard heldContinuations.count < count else { return }

        await withCheckedContinuation { continuation in
            heldWaiters.append((count, continuation))
        }
    }

    func resumeNext() -> Bool {
        guard !heldContinuations.isEmpty else { return false }

        heldContinuations.removeFirst().resume()
        return true
    }

    private func resumeStartWaitersIfNeeded() {
        var remaining: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

        for waiter in startWaiters {
            if started.count >= waiter.count {
                waiter.continuation.resume()
            } else {
                remaining.append(waiter)
            }
        }

        startWaiters = remaining
    }

    private func resumeHeldWaitersIfNeeded() {
        var remaining: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

        for waiter in heldWaiters {
            if heldContinuations.count >= waiter.count {
                waiter.continuation.resume()
            } else {
                remaining.append(waiter)
            }
        }

        heldWaiters = remaining
    }
}

/// Удерживает первые operation до открытия gate, чтобы измерить фактическую, а не созданную TaskGroup параллельность.
private actor BoundedBatchTagSnapshotPipeline {
    private let snapshots: [UUID: TrackRuntimeSnapshot]
    private var isOpen = false
    private var started = 0
    private var running = 0
    private var maximum = 0
    private var heldContinuations: [CheckedContinuation<Void, Never>] = []
    private var startWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var heldWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    var maximumConcurrency: Int {
        maximum
    }

    var startedCount: Int {
        started
    }

    init(snapshots: [UUID: TrackRuntimeSnapshot]) {
        self.snapshots = snapshots
    }

    func loadSnapshot(for trackID: UUID) async -> TrackRuntimeSnapshot? {
        started += 1
        running += 1
        maximum = max(maximum, running)
        resumeStartWaitersIfNeeded()

        if !isOpen {
            await withCheckedContinuation { continuation in
                heldContinuations.append(continuation)
                resumeHeldWaitersIfNeeded()
            }
        }

        running -= 1
        return snapshots[trackID]
    }

    func waitForStartedCount(_ count: Int) async {
        guard started < count else { return }

        await withCheckedContinuation { continuation in
            startWaiters.append((count, continuation))
        }
    }

    func waitForHeldCount(_ count: Int) async {
        guard heldContinuations.count < count else { return }

        await withCheckedContinuation { continuation in
            heldWaiters.append((count, continuation))
        }
    }

    func openAndResumeAll() {
        isOpen = true
        let continuations = heldContinuations
        heldContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }

    private func resumeStartWaitersIfNeeded() {
        var remaining: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
        for waiter in startWaiters {
            if started >= waiter.count {
                waiter.continuation.resume()
            } else {
                remaining.append(waiter)
            }
        }
        startWaiters = remaining
    }

    private func resumeHeldWaitersIfNeeded() {
        var remaining: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
        for waiter in heldWaiters {
            if heldContinuations.count >= waiter.count {
                waiter.continuation.resume()
            } else {
                remaining.append(waiter)
            }
        }
        heldWaiters = remaining
    }
}

@MainActor
private func makeSnapshot(trackID: UUID, title: String) -> TrackRuntimeSnapshot {
    TrackRuntimeSnapshot(
        trackId: trackID,
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
