//
//  RuntimeSnapshotGenerationTests.swift
//  TrackList
//
//  Controlled XCTest для поколений runtime snapshot и поздних async результатов.
//
//  Created by Pavel Fomin on 21.08.2026.
//

import Foundation
import UIKit
import XCTest
@testable import TrackList

@MainActor
final class PlayerRuntimeSnapshotControllerGenerationTests: XCTestCase {

    func testClearDuringBuildDiscardsLateSnapshot() async {
        let trackID = UUID()
        let oldSnapshot = makeRuntimeSnapshot(trackID: trackID, title: "Old")
        let store = RuntimeSnapshotStoreSpy()
        let builder = ControlledRuntimeSnapshotBuilder()
        let artworkProvider = ControlledArtworkProvider()
        let controller = makeController(
            store: store,
            builder: builder,
            artworkProvider: artworkProvider
        )

        let request = Task {
            await controller.requestSnapshotIfNeeded(for: trackID)
        }
        await builder.waitForRequestCount(1, for: trackID)

        controller.clear()
        await builder.completeNext(for: trackID, with: oldSnapshot)

        let changedTrackID = await request.value
        XCTAssertNil(changedTrackID)
        XCTAssertNil(controller.snapshot(for: trackID))
    }

    func testTrackUpdateEventWinsOverLateSnapshotBuild() async {
        let trackID = UUID()
        let oldSnapshot = makeRuntimeSnapshot(trackID: trackID, title: "Old")
        let newSnapshot = makeRuntimeSnapshot(trackID: trackID, title: "New")
        let store = RuntimeSnapshotStoreSpy()
        let builder = ControlledRuntimeSnapshotBuilder()
        let artworkProvider = ControlledArtworkProvider()
        let controller = makeController(
            store: store,
            builder: builder,
            artworkProvider: artworkProvider
        )

        let request = Task {
            await controller.requestSnapshotIfNeeded(for: trackID)
        }
        await builder.waitForRequestCount(1, for: trackID)

        _ = controller.applyTrackUpdateEvent(makeUpdateEvent(snapshot: newSnapshot))
        await builder.completeNext(for: trackID, with: oldSnapshot)

        let changedTrackID = await request.value
        XCTAssertNil(changedTrackID)
        XCTAssertEqual(controller.snapshot(for: trackID), newSnapshot)
    }

    func testLateFirstBuildCannotChangeNewRequestAfterClear() async {
        let trackID = UUID()
        let oldSnapshot = makeRuntimeSnapshot(trackID: trackID, title: "Old")
        let newSnapshot = makeRuntimeSnapshot(trackID: trackID, title: "New")
        let store = RuntimeSnapshotStoreSpy()
        let builder = ControlledRuntimeSnapshotBuilder()
        let artworkProvider = ControlledArtworkProvider()
        let controller = makeController(
            store: store,
            builder: builder,
            artworkProvider: artworkProvider
        )

        let firstRequest = Task {
            await controller.requestSnapshotIfNeeded(for: trackID)
        }
        await builder.waitForRequestCount(1, for: trackID)

        controller.clear()
        let secondRequest = Task {
            await controller.requestSnapshotIfNeeded(for: trackID)
        }
        await builder.waitForRequestCount(2, for: trackID)

        await builder.completeNext(for: trackID, with: oldSnapshot)
        let firstChangedTrackID = await firstRequest.value
        XCTAssertNil(firstChangedTrackID)
        XCTAssertNil(controller.snapshot(for: trackID))

        await builder.completeNext(for: trackID, with: newSnapshot)
        let secondChangedTrackID = await secondRequest.value
        XCTAssertEqual(secondChangedTrackID, trackID)
        XCTAssertEqual(controller.snapshot(for: trackID), newSnapshot)
    }

    func testClearDuringArtworkPreparationDiscardsLateImageWithoutRevision() async {
        let trackID = UUID()
        let artworkData = Data("artwork".utf8)
        let store = RuntimeSnapshotStoreSpy()
        let builder = ControlledRuntimeSnapshotBuilder()
        let artworkProvider = ControlledArtworkProvider()
        let controller = makeController(
            store: store,
            builder: builder,
            artworkProvider: artworkProvider
        )

        let request = Task {
            await controller.requestNowPlayingArtworkIfNeeded(
                for: trackID,
                artworkData: artworkData,
                sourceIdentifier: .embeddedArtwork(data: artworkData),
                revision: nil
            )
        }
        await artworkProvider.waitForRequestCount(1)

        controller.clear()
        await artworkProvider.completeNext(with: makeArtworkImage())

        let changedTrackID = await request.value
        XCTAssertNil(changedTrackID)
        XCTAssertNil(controller.nowPlayingArtwork(for: trackID))
    }

    func testExistingLocalAndSharedSnapshotsKeepFastPaths() async {
        let storedTrackID = UUID()
        let localTrackID = UUID()
        let storedSnapshot = makeRuntimeSnapshot(trackID: storedTrackID, title: "Stored")
        let localSnapshot = makeRuntimeSnapshot(trackID: localTrackID, title: "Local")
        let store = RuntimeSnapshotStoreSpy(snapshots: [storedTrackID: storedSnapshot])
        let builder = ControlledRuntimeSnapshotBuilder()
        let artworkProvider = ControlledArtworkProvider()
        let controller = makeController(
            store: store,
            builder: builder,
            artworkProvider: artworkProvider
        )

        let storedChangedTrackID = await controller.requestSnapshotIfNeeded(for: storedTrackID)
        _ = controller.applyTrackUpdateEvent(makeUpdateEvent(snapshot: localSnapshot))
        let localChangedTrackID = await controller.requestSnapshotIfNeeded(for: localTrackID)
        let storedBuildCount = await builder.requestCount(for: storedTrackID)
        let localBuildCount = await builder.requestCount(for: localTrackID)

        XCTAssertEqual(storedChangedTrackID, storedTrackID)
        XCTAssertEqual(controller.snapshot(for: storedTrackID), storedSnapshot)
        XCTAssertNil(localChangedTrackID)
        XCTAssertEqual(controller.snapshot(for: localTrackID), localSnapshot)
        XCTAssertEqual(storedBuildCount, 0)
        XCTAssertEqual(localBuildCount, 0)
    }

    private func makeController(
        store: RuntimeSnapshotStoreSpy,
        builder: ControlledRuntimeSnapshotBuilder,
        artworkProvider: ControlledArtworkProvider
    ) -> PlayerRuntimeSnapshotController {
        PlayerRuntimeSnapshotController(
            runtimeSnapshotStore: store,
            runtimeSnapshotBuilder: builder,
            artworkProvider: artworkProvider
        )
    }
}

@MainActor
final class LibraryTrackRuntimeControllerGenerationTests: XCTestCase {

    func testClearDuringBuildDiscardsLateSnapshotAndSkipsSharedStoreWrite() async {
        let trackID = UUID()
        let oldSnapshot = makeRuntimeSnapshot(trackID: trackID, title: "Old")
        let store = RuntimeSnapshotStoreSpy()
        let builder = ControlledRuntimeSnapshotBuilder()
        let controller = makeController(store: store, builder: builder)

        let request = Task {
            await controller.loadSnapshotIfNeeded(for: trackID)
        }
        await builder.waitForRequestCount(1, for: trackID)

        controller.clearSnapshots()
        await builder.completeNext(for: trackID, with: oldSnapshot)

        let result = await request.value
        XCTAssertNil(result)
        XCTAssertNil(controller.snapshot(for: trackID))
        XCTAssertNil(store.snapshot(forTrackId: trackID))
        XCTAssertEqual(store.storeCallCount, 0)
    }

    func testTrackUpdateEventWinsOverLateBuildWithoutStoreOverwrite() async {
        let trackID = UUID()
        let oldSnapshot = makeRuntimeSnapshot(trackID: trackID, title: "Old")
        let newSnapshot = makeRuntimeSnapshot(trackID: trackID, title: "New")
        let store = RuntimeSnapshotStoreSpy()
        let builder = ControlledRuntimeSnapshotBuilder()
        let controller = makeController(store: store, builder: builder)

        let request = Task {
            await controller.loadSnapshotIfNeeded(for: trackID)
        }
        await builder.waitForRequestCount(1, for: trackID)

        controller.applyTrackUpdateEvents([makeUpdateEvent(snapshot: newSnapshot)])
        await builder.completeNext(for: trackID, with: oldSnapshot)

        let result = await request.value
        XCTAssertNil(result)
        XCTAssertEqual(controller.snapshot(for: trackID), newSnapshot)
        XCTAssertNotEqual(store.snapshot(forTrackId: trackID), oldSnapshot)
        XCTAssertEqual(store.storeCallCount, 0)
    }

    func testOldCompletionCannotFinishNewLoadingOperationOrItsWaiter() async {
        let trackID = UUID()
        let oldSnapshot = makeRuntimeSnapshot(trackID: trackID, title: "Old")
        let newSnapshot = makeRuntimeSnapshot(trackID: trackID, title: "New")
        let store = RuntimeSnapshotStoreSpy()
        let builder = ControlledRuntimeSnapshotBuilder()
        let completionRecorder = SnapshotResultRecorder()
        let controller = makeController(store: store, builder: builder)

        let first = Task {
            await controller.loadSnapshotIfNeeded(for: trackID)
        }
        await builder.waitForRequestCount(1, for: trackID)

        controller.clearSnapshots()
        let second = Task {
            await controller.loadSnapshotIfNeeded(for: trackID)
        }
        await builder.waitForRequestCount(2, for: trackID)

        let secondWaiter = Task {
            let result = await controller.loadSnapshotIfNeeded(for: trackID)
            await completionRecorder.record(result)
            return result
        }
        await Task.yield()

        await builder.completeNext(for: trackID, with: oldSnapshot)
        let firstResult = await first.value
        await Task.yield()

        let completionCountBeforeCurrentBuild = await completionRecorder.count()

        XCTAssertNil(firstResult)
        XCTAssertEqual(completionCountBeforeCurrentBuild, 0)

        await builder.completeNext(for: trackID, with: newSnapshot)
        let secondResult = await second.value
        let secondWaiterResult = await secondWaiter.value

        let completionValues = await completionRecorder.values()

        XCTAssertEqual(secondResult, newSnapshot)
        XCTAssertEqual(secondWaiterResult, newSnapshot)
        XCTAssertEqual(completionValues, [newSnapshot])
        XCTAssertEqual(controller.snapshot(for: trackID), newSnapshot)
    }

    func testStaleWaiterReceivesNilInsteadOfOldSnapshot() async {
        let trackID = UUID()
        let oldSnapshot = makeRuntimeSnapshot(trackID: trackID, title: "Old")
        let newSnapshot = makeRuntimeSnapshot(trackID: trackID, title: "New")
        let store = RuntimeSnapshotStoreSpy()
        let builder = ControlledRuntimeSnapshotBuilder()
        let controller = makeController(store: store, builder: builder)

        let loader = Task {
            await controller.loadSnapshotIfNeeded(for: trackID)
        }
        await builder.waitForRequestCount(1, for: trackID)

        let waiter = Task {
            await controller.loadSnapshotIfNeeded(for: trackID)
        }
        await Task.yield()

        controller.applyTrackUpdateEvents([makeUpdateEvent(snapshot: newSnapshot)])
        let waiterResult = await waiter.value
        await builder.completeNext(for: trackID, with: oldSnapshot)
        let loaderResult = await loader.value

        XCTAssertNil(waiterResult)
        XCTAssertNil(loaderResult)
        XCTAssertNotEqual(waiterResult, oldSnapshot)
        XCTAssertEqual(controller.snapshot(for: trackID), newSnapshot)
    }

    func testSameTrackConsumersShareOneCurrentBuildAndStoreItsSnapshot() async {
        let trackID = UUID()
        let expectedSnapshot = makeRuntimeSnapshot(trackID: trackID, title: "Expected")
        let store = RuntimeSnapshotStoreSpy()
        let builder = ControlledRuntimeSnapshotBuilder()
        let controller = makeController(store: store, builder: builder)

        let first = Task {
            await controller.loadSnapshotIfNeeded(for: trackID)
        }
        await builder.waitForRequestCount(1, for: trackID)

        let second = Task {
            await controller.loadSnapshotIfNeeded(for: trackID)
        }
        await Task.yield()

        let buildCountBeforeCompletion = await builder.requestCount(for: trackID)
        XCTAssertEqual(buildCountBeforeCompletion, 1)

        await builder.completeNext(for: trackID, with: expectedSnapshot)
        let firstResult = await first.value
        let secondResult = await second.value

        XCTAssertEqual(firstResult, expectedSnapshot)
        XCTAssertEqual(secondResult, expectedSnapshot)
        XCTAssertEqual(controller.snapshot(for: trackID), expectedSnapshot)
        XCTAssertEqual(store.snapshot(forTrackId: trackID), expectedSnapshot)
        XCTAssertEqual(store.storeCallCount, 1)
    }

    func testUpdateForOtherTrackDoesNotInvalidateCurrentBuild() async {
        let loadingTrackID = UUID()
        let updatedTrackID = UUID()
        let loadingSnapshot = makeRuntimeSnapshot(trackID: loadingTrackID, title: "Loading")
        let updatedSnapshot = makeRuntimeSnapshot(trackID: updatedTrackID, title: "Updated")
        let store = RuntimeSnapshotStoreSpy()
        let builder = ControlledRuntimeSnapshotBuilder()
        let controller = makeController(store: store, builder: builder)

        let request = Task {
            await controller.loadSnapshotIfNeeded(for: loadingTrackID)
        }
        await builder.waitForRequestCount(1, for: loadingTrackID)

        controller.applyTrackUpdateEvents([makeUpdateEvent(snapshot: updatedSnapshot)])
        await builder.completeNext(for: loadingTrackID, with: loadingSnapshot)

        let result = await request.value
        XCTAssertEqual(result, loadingSnapshot)
        XCTAssertEqual(controller.snapshot(for: loadingTrackID), loadingSnapshot)
        XCTAssertEqual(controller.snapshot(for: updatedTrackID), updatedSnapshot)
        XCTAssertEqual(store.snapshot(forTrackId: loadingTrackID), loadingSnapshot)
    }

    func testClearInvalidatesMultipleInFlightTracksWithoutStoreWrites() async {
        let firstTrackID = UUID()
        let secondTrackID = UUID()
        let firstSnapshot = makeRuntimeSnapshot(trackID: firstTrackID, title: "First")
        let secondSnapshot = makeRuntimeSnapshot(trackID: secondTrackID, title: "Second")
        let store = RuntimeSnapshotStoreSpy()
        let builder = ControlledRuntimeSnapshotBuilder()
        let controller = makeController(store: store, builder: builder)

        let first = Task {
            await controller.loadSnapshotIfNeeded(for: firstTrackID)
        }
        let second = Task {
            await controller.loadSnapshotIfNeeded(for: secondTrackID)
        }
        await builder.waitForRequestCount(1, for: firstTrackID)
        await builder.waitForRequestCount(1, for: secondTrackID)

        controller.clearSnapshots()
        await builder.completeNext(for: firstTrackID, with: firstSnapshot)
        await builder.completeNext(for: secondTrackID, with: secondSnapshot)

        let firstResult = await first.value
        let secondResult = await second.value

        XCTAssertNil(firstResult)
        XCTAssertNil(secondResult)
        XCTAssertNil(controller.snapshot(for: firstTrackID))
        XCTAssertNil(controller.snapshot(for: secondTrackID))
        XCTAssertNil(store.snapshot(forTrackId: firstTrackID))
        XCTAssertNil(store.snapshot(forTrackId: secondTrackID))
        XCTAssertEqual(store.storeCallCount, 0)
    }

    func testRequestQueuedBeforeClearDoesNotStartBuildInNewGeneration() async {
        let trackID = UUID()
        let store = RuntimeSnapshotStoreSpy()
        let builder = ControlledRuntimeSnapshotBuilder()
        let controller = makeController(store: store, builder: builder)

        // Task запроса не получает main actor, пока синхронная очистка не завершится.
        controller.requestSnapshotIfNeeded(for: trackID)
        controller.clearSnapshots()
        await Task.yield()

        let buildCount = await builder.requestCount(for: trackID)

        XCTAssertEqual(buildCount, 0)
        XCTAssertNil(controller.snapshot(for: trackID))
        XCTAssertNil(store.snapshot(forTrackId: trackID))
    }

    func testExistingLocalAndSharedSnapshotsKeepFastPaths() async {
        let storedTrackID = UUID()
        let localTrackID = UUID()
        let storedSnapshot = makeRuntimeSnapshot(trackID: storedTrackID, title: "Stored")
        let localSnapshot = makeRuntimeSnapshot(trackID: localTrackID, title: "Local")
        let store = RuntimeSnapshotStoreSpy(snapshots: [storedTrackID: storedSnapshot])
        let builder = ControlledRuntimeSnapshotBuilder()
        let controller = makeController(store: store, builder: builder)

        let storedResult = await controller.loadSnapshotIfNeeded(for: storedTrackID)
        controller.applyTrackUpdateEvents([makeUpdateEvent(snapshot: localSnapshot)])
        let localResult = await controller.loadSnapshotIfNeeded(for: localTrackID)
        let storedBuildCount = await builder.requestCount(for: storedTrackID)
        let localBuildCount = await builder.requestCount(for: localTrackID)

        XCTAssertEqual(storedResult, storedSnapshot)
        XCTAssertEqual(localResult, localSnapshot)
        XCTAssertEqual(storedBuildCount, 0)
        XCTAssertEqual(localBuildCount, 0)
    }

    private func makeController(
        store: RuntimeSnapshotStoreSpy,
        builder: ControlledRuntimeSnapshotBuilder
    ) -> LibraryTrackRuntimeController {
        LibraryTrackRuntimeController(
            runtimeSnapshotStore: store,
            runtimeSnapshotBuilder: builder
        )
    }
}

@MainActor
private final class RuntimeSnapshotStoreSpy: TrackRuntimeSnapshotStoring {
    private var snapshotsByTrackID: [UUID: TrackRuntimeSnapshot]
    private(set) var storeCallCount = 0

    init(snapshots: [UUID: TrackRuntimeSnapshot] = [:]) {
        snapshotsByTrackID = snapshots
    }

    func snapshot(forTrackId trackId: UUID) -> TrackRuntimeSnapshot? {
        snapshotsByTrackID[trackId]
    }

    func storeSnapshot(_ snapshot: TrackRuntimeSnapshot) {
        storeCallCount += 1
        snapshotsByTrackID[snapshot.trackId] = snapshot
    }
}

private actor ControlledRuntimeSnapshotBuilder: TrackRuntimeSnapshotBuilding {
    private struct RequestWaiter {
        let trackID: UUID
        let requiredCount: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private var requestCounts: [UUID: Int] = [:]
    private var continuations: [UUID: [CheckedContinuation<TrackRuntimeSnapshot?, Never>]] = [:]
    private var requestWaiters: [RequestWaiter] = []

    /// Удерживает build до явного completion, задавая порядок late-result без ожиданий по времени.
    func buildSnapshot(forTrackId trackId: UUID) async throws -> TrackRuntimeSnapshot? {
        requestCounts[trackId, default: 0] += 1

        return await withCheckedContinuation { continuation in
            continuations[trackId, default: []].append(continuation)
            resumeRequestWaitersIfNeeded()
        }
    }

    func waitForRequestCount(_ requiredCount: Int, for trackID: UUID) async {
        guard requestCounts[trackID, default: 0] < requiredCount else {
            return
        }

        await withCheckedContinuation { continuation in
            requestWaiters.append(
                RequestWaiter(
                    trackID: trackID,
                    requiredCount: requiredCount,
                    continuation: continuation
                )
            )
        }
    }

    func completeNext(for trackID: UUID, with snapshot: TrackRuntimeSnapshot?) {
        guard var pending = continuations[trackID], pending.isEmpty == false else {
            XCTFail("Не найден удержанный runtime snapshot build для \(trackID)")
            return
        }

        let continuation = pending.removeFirst()
        continuations[trackID] = pending.isEmpty ? nil : pending
        continuation.resume(returning: snapshot)
    }

    func requestCount(for trackID: UUID) -> Int {
        requestCounts[trackID, default: 0]
    }

    private func resumeRequestWaitersIfNeeded() {
        var remainingWaiters: [RequestWaiter] = []

        for waiter in requestWaiters {
            if requestCounts[waiter.trackID, default: 0] >= waiter.requiredCount {
                waiter.continuation.resume()
            } else {
                remainingWaiters.append(waiter)
            }
        }

        requestWaiters = remainingWaiters
    }
}

private actor ControlledArtworkProvider: ArtworkImageProviding {
    private var requestCount = 0
    private var continuations: [CheckedContinuation<UIImage?, Never>] = []
    private var requestWaiters: [CheckedContinuation<Void, Never>] = []

    func image(for request: ArtworkRequest) async -> UIImage? {
        requestCount += 1
        resumeRequestWaitersIfNeeded()

        return await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func waitForRequestCount(_ requiredCount: Int) async {
        guard requestCount < requiredCount else {
            return
        }

        await withCheckedContinuation { continuation in
            requestWaiters.append(continuation)
        }
    }

    func completeNext(with image: UIImage?) {
        guard continuations.isEmpty == false else {
            XCTFail("Не найдена удержанная подготовка artwork")
            return
        }

        continuations.removeFirst().resume(returning: image)
    }

    private func resumeRequestWaitersIfNeeded() {
        guard requestCount > 0 else { return }

        let waiters = requestWaiters
        requestWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }
}

private actor SnapshotResultRecorder {
    private var results: [TrackRuntimeSnapshot?] = []

    func record(_ result: TrackRuntimeSnapshot?) {
        results.append(result)
    }

    func count() -> Int {
        results.count
    }

    func values() -> [TrackRuntimeSnapshot?] {
        results
    }
}

@MainActor
private func makeRuntimeSnapshot(trackID: UUID, title: String) -> TrackRuntimeSnapshot {
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

@MainActor
private func makeUpdateEvent(snapshot: TrackRuntimeSnapshot) -> TrackUpdateEvent {
    TrackUpdateEvent(
        trackId: snapshot.trackId,
        reason: .metadataUpdated,
        changedFields: [.title],
        snapshot: snapshot
    )
}

@MainActor
private func makeArtworkImage() -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
    return renderer.image { context in
        UIColor.red.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
}
