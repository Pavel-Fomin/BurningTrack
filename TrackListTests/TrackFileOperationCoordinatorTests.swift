//
//  TrackFileOperationCoordinatorTests.swift
//  TrackList
//
//  Controlled-проверки per-track ownership файловых операций.
//
//  Created by Pavel Fomin on 21.08.2026.
//

import Foundation
import XCTest
@testable import TrackList

/// Проверяет FIFO ownership без файловой системы, SQLite и production singleton-ов.
@MainActor
final class TrackFileOperationCoordinatorTests: XCTestCase {

    func testSameTrackOperationsRunSerially() async throws {
        let coordinator = TrackFileOperationCoordinator()
        let events = TrackFileOperationEventLog()
        let firstGate = TrackFileOperationGate()
        let trackId = UUID()

        let first = Task {
            try await coordinator.run(trackId: trackId) {
                await events.record("first")
                await firstGate.wait()
            }
        }
        await events.wait(for: "first")

        let second = Task {
            try await coordinator.run(trackId: trackId) {
                await events.record("second")
            }
        }
        await allowQueuedTasksToReachCoordinator()

        let eventsBeforeRelease = await events.values()
        XCTAssertEqual(eventsBeforeRelease, ["first"])

        await firstGate.open()
        try await first.value
        try await second.value

        let finalEvents = await events.values()
        XCTAssertEqual(finalEvents, ["first", "second"])
    }

    func testDifferentTracksRunInParallel() async throws {
        let coordinator = TrackFileOperationCoordinator()
        let events = TrackFileOperationEventLog()
        let firstGate = TrackFileOperationGate()
        let secondGate = TrackFileOperationGate()

        let first = Task {
            try await coordinator.run(trackId: UUID()) {
                await events.record("first")
                await firstGate.wait()
            }
        }
        await events.wait(for: "first")

        let second = Task {
            try await coordinator.run(trackId: UUID()) {
                await events.record("second")
                await secondGate.wait()
            }
        }
        await events.wait(for: "second")

        let eventsBeforeRelease = await events.values()
        XCTAssertEqual(Set(eventsBeforeRelease), Set(["first", "second"]))

        await firstGate.open()
        await secondGate.open()
        try await first.value
        try await second.value
    }

    func testSameTrackOperationsKeepFIFOOrder() async throws {
        let coordinator = TrackFileOperationCoordinator()
        let events = TrackFileOperationEventLog()
        let firstGate = TrackFileOperationGate()
        let trackId = UUID()

        let first = Task {
            try await coordinator.run(trackId: trackId) {
                await events.record("first")
                await firstGate.wait()
            }
        }
        await events.wait(for: "first")

        let second = Task {
            try await coordinator.run(trackId: trackId) {
                await events.record("second")
            }
        }
        await allowQueuedTasksToReachCoordinator()

        let third = Task {
            try await coordinator.run(trackId: trackId) {
                await events.record("third")
            }
        }
        await allowQueuedTasksToReachCoordinator()
        await firstGate.open()

        try await first.value
        try await second.value
        try await third.value

        let finalEvents = await events.values()
        XCTAssertEqual(finalEvents, ["first", "second", "third"])
    }

    func testQueuedCancellationSkipsOperationAndKeepsFollowingFIFOWaiter() async throws {
        let coordinator = TrackFileOperationCoordinator()
        let events = TrackFileOperationEventLog()
        let firstGate = TrackFileOperationGate()
        let trackId = UUID()

        let first = Task {
            try await coordinator.run(trackId: trackId) {
                await events.record("first")
                await firstGate.wait()
            }
        }
        await events.wait(for: "first")

        let cancelled = Task {
            try await coordinator.run(trackId: trackId) {
                await events.record("cancelled")
            }
        }
        await allowQueuedTasksToReachCoordinator()

        let third = Task {
            try await coordinator.run(trackId: trackId) {
                await events.record("third")
            }
        }
        await allowQueuedTasksToReachCoordinator()

        cancelled.cancel()
        await allowQueuedTasksToReachCoordinator()
        await firstGate.open()

        try await first.value
        try await third.value
        do {
            try await cancelled.value
            XCTFail("Отменённая операция не должна получить ownership")
        } catch is CancellationError {
            // Ожидаемый результат: body отменённого waiter-а не запускался.
        }

        let finalEvents = await events.values()
        XCTAssertEqual(finalEvents, ["first", "third"])
    }

    func testRunningCancellationReleasesTrackOnlyAfterOperationBodyExits() async throws {
        let coordinator = TrackFileOperationCoordinator()
        let events = TrackFileOperationEventLog()
        let firstGate = TrackFileOperationGate()
        let trackId = UUID()

        let first = Task {
            try await coordinator.run(trackId: trackId) {
                await events.record("first")
                await firstGate.wait()
                try Task.checkCancellation()
            }
        }
        await events.wait(for: "first")

        let second = Task {
            try await coordinator.run(trackId: trackId) {
                await events.record("second")
            }
        }
        await allowQueuedTasksToReachCoordinator()
        first.cancel()
        await allowQueuedTasksToReachCoordinator()

        let eventsBeforeBodyExit = await events.values()
        XCTAssertEqual(eventsBeforeBodyExit, ["first"])

        await firstGate.open()
        do {
            try await first.value
            XCTFail("Running operation должна вернуть CancellationError после выхода body")
        } catch is CancellationError {
            // Ownership освобождён после фактического выхода body.
        }
        try await second.value

        let finalEvents = await events.values()
        XCTAssertEqual(finalEvents, ["first", "second"])
    }

    func testFailureReleasesTrackForNextOperation() async throws {
        let coordinator = TrackFileOperationCoordinator()
        let events = TrackFileOperationEventLog()
        let firstGate = TrackFileOperationGate()
        let trackId = UUID()

        let first = Task {
            try await coordinator.run(trackId: trackId) {
                await events.record("first")
                await firstGate.wait()
                throw TrackFileOperationTestError.failed
            }
        }
        await events.wait(for: "first")

        let second = Task {
            try await coordinator.run(trackId: trackId) {
                await events.record("second")
            }
        }
        await allowQueuedTasksToReachCoordinator()
        await firstGate.open()

        do {
            try await first.value
            XCTFail("Ошибка первой операции должна вернуться только её caller-у")
        } catch TrackFileOperationTestError.failed {
            // Ожидаемая ошибка первой операции.
        }
        try await second.value

        let finalEvents = await events.values()
        XCTAssertEqual(finalEvents, ["first", "second"])
    }

    func testCompletedTrackStateDoesNotBlockNewOperation() async throws {
        let coordinator = TrackFileOperationCoordinator()
        let events = TrackFileOperationEventLog()
        let trackId = UUID()

        try await coordinator.run(trackId: trackId) {
            await events.record("first")
        }
        try await coordinator.run(trackId: trackId) {
            await events.record("second")
        }

        // Повторное получение ownership после завершения доказывает, что stale state не удерживает очередь.
        let finalEvents = await events.values()
        XCTAssertEqual(finalEvents, ["first", "second"])
    }

    func testRenameKeepsMoveOutUntilPostUpdateCompletes() async throws {
        let trackId = UUID()
        let events = TrackFileOperationEventLog()
        let fileURLResolver = TrackFileURLResolverSpy(initialURL: makeURL(name: "Original.mp3"))
        let renameGate = TrackFileOperationGate()
        let postUpdateGate = TrackFileOperationGate()
        let fileManager = TrackFileManagerSpy(
            urlResolver: fileURLResolver,
            events: events,
            renameGate: renameGate,
            moveGate: TrackFileOperationGate(isOpen: true)
        )
        let postUpdater = TrackPostUpdateHandlerSpy(events: events, updateGate: postUpdateGate)
        let executor = makeExecutor(
            fileManager: fileManager,
            fileURLResolver: fileURLResolver,
            postUpdater: postUpdater
        )
        let busyChecker = TrackFileBusyCheckerStub()

        let rename = Task {
            try await executor.renameTrack(
                trackId: trackId,
                to: "Renamed.mp3",
                using: busyChecker
            )
        }
        await events.wait(for: "rename:Renamed.mp3")
        await renameGate.open()
        await events.wait(for: "post")

        let move = Task {
            try await executor.moveTrack(
                trackId: trackId,
                toFolder: UUID(),
                using: busyChecker
            )
        }
        await allowQueuedTasksToReachCoordinator()

        let eventsBeforePostUpdate = await events.values()
        XCTAssertFalse(eventsBeforePostUpdate.contains("move"))

        await postUpdateGate.open()
        _ = try await rename.value
        _ = try await move.value

        let finalEvents = await events.values()
        XCTAssertEqual(finalEvents, ["rename:Renamed.mp3", "post", "move", "post"])
    }

    func testRepeatedRenameResolvesPreviousURLAfterEarlierRenameCompletes() async throws {
        let trackId = UUID()
        let events = TrackFileOperationEventLog()
        let fileURLResolver = TrackFileURLResolverSpy(initialURL: makeURL(name: "Original.mp3"))
        let renameGate = TrackFileOperationGate(isOpen: true)
        let postUpdateGate = TrackFileOperationGate()
        let fileManager = TrackFileManagerSpy(
            urlResolver: fileURLResolver,
            events: events,
            renameGate: renameGate,
            moveGate: TrackFileOperationGate(isOpen: true)
        )
        let postUpdater = TrackPostUpdateHandlerSpy(events: events, updateGate: postUpdateGate)
        let executor = makeExecutor(
            fileManager: fileManager,
            fileURLResolver: fileURLResolver,
            postUpdater: postUpdater
        )
        let busyChecker = TrackFileBusyCheckerStub()

        let first = Task {
            try await executor.renameTrack(
                trackId: trackId,
                to: "First.mp3",
                using: busyChecker
            )
        }
        await events.wait(for: "post")

        let second = Task {
            try await executor.renameTrack(
                trackId: trackId,
                to: "Second.mp3",
                using: busyChecker
            )
        }
        await allowQueuedTasksToReachCoordinator()

        let urlsBeforeRelease = await fileURLResolver.resolvedFileNames()
        XCTAssertEqual(urlsBeforeRelease, ["Original.mp3"])

        await postUpdateGate.open()
        _ = try await first.value
        _ = try await second.value

        let resolvedFileNames = await fileURLResolver.resolvedFileNames()
        XCTAssertEqual(resolvedFileNames, ["Original.mp3", "First.mp3"])
    }

    func testTagWriteAndRenameOfSameTrackDoNotOverlap() async throws {
        let trackId = UUID()
        let events = TrackFileOperationEventLog()
        let fileURLResolver = TrackFileURLResolverSpy(initialURL: makeURL(name: "Original.mp3"))
        let tagWriteGate = TrackFileOperationGate()
        let fileManager = TrackFileManagerSpy(
            urlResolver: fileURLResolver,
            events: events,
            renameGate: TrackFileOperationGate(isOpen: true),
            moveGate: TrackFileOperationGate(isOpen: true)
        )
        let postUpdater = TrackPostUpdateHandlerSpy(
            events: events,
            updateGate: TrackFileOperationGate(isOpen: true)
        )
        let executor = makeExecutor(
            fileManager: fileManager,
            fileURLResolver: fileURLResolver,
            postUpdater: postUpdater,
            tagsWriter: TrackTagsWriterSpy(events: events, writeGate: tagWriteGate)
        )
        let busyChecker = TrackFileBusyCheckerStub()

        let tagWrite = Task {
            try await executor.updateTrackTags(
                trackId: trackId,
                patch: TagWritePatch(),
                artworkAction: .none
            )
        }
        await events.wait(for: "tag write")

        let rename = Task {
            try await executor.renameTrack(
                trackId: trackId,
                to: "Renamed.mp3",
                using: busyChecker
            )
        }
        await allowQueuedTasksToReachCoordinator()

        let eventsBeforeTagCompletion = await events.values()
        XCTAssertFalse(eventsBeforeTagCompletion.contains("rename:Renamed.mp3"))

        await tagWriteGate.open()
        _ = try await tagWrite.value
        _ = try await rename.value

        let finalEvents = await events.values()
        XCTAssertEqual(finalEvents, ["tag write", "post", "rename:Renamed.mp3", "post"])
    }

    func testBatchRenameKeepsSameTrackSingleRenameOutOfProtectedSection() async throws {
        let firstTrackId = UUID()
        let secondTrackId = UUID()
        let events = TrackFileOperationEventLog()
        let fileURLResolver = TrackFileURLResolverSpy(initialURL: makeURL(name: "Original.mp3"))
        let renameGate = TrackFileOperationGate()
        let fileManager = TrackFileManagerSpy(
            urlResolver: fileURLResolver,
            events: events,
            renameGate: renameGate,
            moveGate: TrackFileOperationGate(isOpen: true)
        )
        let postUpdater = TrackPostUpdateHandlerSpy(
            events: events,
            updateGate: TrackFileOperationGate(isOpen: true)
        )
        let executor = makeExecutor(
            fileManager: fileManager,
            fileURLResolver: fileURLResolver,
            postUpdater: postUpdater
        )
        let busyChecker = TrackFileBusyCheckerStub()

        let batch = Task {
            await executor.renameTrackFilesBatch(
                [
                    BatchFilenameRenameCommand(
                        trackId: firstTrackId,
                        currentFileName: "Original.mp3",
                        targetFileName: "Batch First.mp3"
                    ),
                    BatchFilenameRenameCommand(
                        trackId: secondTrackId,
                        currentFileName: "Second.mp3",
                        targetFileName: "Batch Second.mp3"
                    )
                ],
                using: busyChecker
            )
        }
        await events.wait(for: "rename:Batch First.mp3")

        let singleRename = Task {
            try await executor.renameTrack(
                trackId: firstTrackId,
                to: "Single.mp3",
                using: busyChecker
            )
        }
        await allowQueuedTasksToReachCoordinator()

        let eventsBeforeBatchRelease = await events.values()
        XCTAssertFalse(eventsBeforeBatchRelease.contains("rename:Single.mp3"))

        await renameGate.open()
        let batchResult = await batch.value
        XCTAssertEqual(batchResult.successCount, 2)
        XCTAssertEqual(batchResult.failureCount, 0)
        _ = try await singleRename.value

        let finalEvents = await events.values()
        XCTAssertEqual(
            finalEvents,
            [
                "rename:Batch First.mp3",
                "prepare",
                "rename:Batch Second.mp3",
                "prepare",
                "batch publish",
                "rename:Single.mp3",
                "post"
            ]
        )
    }

    func testRenameDoesNotReturnConfirmedResultWhenPostUpdateFails() async {
        let trackId = UUID()
        let events = TrackFileOperationEventLog()
        let fileURLResolver = TrackFileURLResolverSpy(initialURL: makeURL(name: "Original.mp3"))
        let fileManager = TrackFileManagerSpy(
            urlResolver: fileURLResolver,
            events: events,
            renameGate: TrackFileOperationGate(isOpen: true),
            moveGate: TrackFileOperationGate(isOpen: true)
        )
        let executor = makeExecutor(
            fileManager: fileManager,
            fileURLResolver: fileURLResolver,
            postUpdater: TrackPostUpdateFailureSpy()
        )

        do {
            _ = try await executor.renameTrack(
                trackId: trackId,
                to: "Renamed.mp3",
                using: TrackFileBusyCheckerStub()
            )
            XCTFail("Переименование без подтверждённого post-update не должно вернуть confirmed result")
        } catch let failure as MutationFailure {
            XCTAssertEqual(failure.stage, .confirm)
            XCTAssertEqual(failure.appError, .trackUpdateConfirmationFailed)
            XCTAssertEqual(failure.recovery, .confirmationMissing)
        } catch {
            XCTFail("Ожидалась MutationFailure, получено: \(error)")
        }
    }

    func testPurchasedITunesCopyDoesNotReturnSuccessWhenSyncIsSkipped() async {
        let copiedFileURL = URL(fileURLWithPath: "/tmp/library/Imported.m4a")
        let rootURL = URL(fileURLWithPath: "/tmp/library")
        let executor = AppCommandExecutor(
            purchasedITunesTrackCopier: PurchasedITunesTrackCopyStub(
                result: PurchasedITunesTrackCopyResult(
                    fileURL: copiedFileURL,
                    folderId: UUID(),
                    folderName: "Library",
                    rootFolderId: UUID(),
                    rootFolderURL: rootURL
                )
            ),
            libraryRootSyncer: LibraryRootSyncStub(
                outcome: .skipped(.emptyScanProtected)
            )
        )

        do {
            _ = try await executor.copyPurchasedITunesTrack(
                makePurchasedITunesTrack(),
                toFolder: UUID()
            )
            XCTFail("Пропущенный sync не должен подтверждать импорт iTunes-трека")
        } catch let failure as MutationFailure {
            XCTAssertEqual(failure.stage, .confirm)
            XCTAssertEqual(failure.appError, .purchasedITunesCopyFailed)
            XCTAssertEqual(failure.recovery, .confirmationMissing)
        } catch {
            XCTFail("Ожидалась MutationFailure, получено: \(error)")
        }
    }

    /// Даёт созданным задачам дойти до actor-owned continuation без busy-wait в production-коде.
    private func allowQueuedTasksToReachCoordinator() async {
        try? await Task.sleep(nanoseconds: 20_000_000)
    }

    /// Собирает executor из узких controlled capabilities вместо production Library и SQLite.
    private func makeExecutor(
        fileManager: any TrackFileOperationManaging,
        fileURLResolver: any TrackFileURLResolving,
        postUpdater: any TrackPostUpdateHandling,
        tagsWriter: any TagsWriter = TrackTagsWriterSpy(
            events: TrackFileOperationEventLog(),
            writeGate: TrackFileOperationGate(isOpen: true)
        )
    ) -> AppCommandExecutor {
        AppCommandExecutor(
            trackFileOperationCoordinator: TrackFileOperationCoordinator(),
            trackFileManager: fileManager,
            trackFileURLResolver: fileURLResolver,
            trackPostUpdateHandler: postUpdater,
            trackFolderNameResolver: TrackFolderNameResolverStub(),
            tagsWriter: tagsWriter
        )
    }

    /// Строит test-only URL без обращения к пользовательской Library.
    private func makeURL(name: String) -> URL {
        URL(fileURLWithPath: "/tmp/track-file-operation-tests/\(name)")
    }

    /// Создаёт доступный iTunes-ассет для изолированной проверки command pipeline.
    private func makePurchasedITunesTrack() -> PurchasedITunesPlayableTrack {
        PurchasedITunesPlayableTrack(
            track: PurchasedITunesTrack(
                id: 1,
                title: "Purchased",
                artist: "Artist",
                album: nil,
                year: nil,
                genre: nil,
                dateAdded: Date(timeIntervalSince1970: 0),
                artworkData: nil,
                duration: 180,
                assetURL: URL(fileURLWithPath: "/tmp/purchased.m4a")
            )
        )
    }
}

/// Gate удерживает controlled operation до явного release тестом.
private actor TrackFileOperationGate {
    private var isOpen: Bool
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(isOpen: Bool = false) {
        self.isOpen = isOpen
    }

    func wait() async {
        guard isOpen == false else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        guard isOpen == false else { return }
        isOpen = true
        let currentWaiters = waiters
        waiters.removeAll()
        currentWaiters.forEach { $0.resume() }
    }
}

/// Запоминает порядок видимых контрольных точек и позволяет ждать конкретное событие.
private actor TrackFileOperationEventLog {
    private var recordedValues: [String] = []
    private var continuationsByValue: [String: [CheckedContinuation<Void, Never>]] = [:]

    func record(_ value: String) {
        recordedValues.append(value)
        let continuations = continuationsByValue.removeValue(forKey: value) ?? []
        continuations.forEach { $0.resume() }
    }

    func wait(for value: String) async {
        guard recordedValues.contains(value) == false else { return }
        await withCheckedContinuation { continuation in
            continuationsByValue[value, default: []].append(continuation)
        }
    }

    func values() -> [String] {
        recordedValues
    }
}

/// Controlled file manager фиксирует начало физической мутации и обновляет следующий bookmark URL.
private actor TrackFileManagerSpy: TrackFileOperationManaging {
    private let urlResolver: TrackFileURLResolverSpy
    private let events: TrackFileOperationEventLog
    private let renameGate: TrackFileOperationGate
    private let moveGate: TrackFileOperationGate

    init(
        urlResolver: TrackFileURLResolverSpy,
        events: TrackFileOperationEventLog,
        renameGate: TrackFileOperationGate,
        moveGate: TrackFileOperationGate
    ) {
        self.urlResolver = urlResolver
        self.events = events
        self.renameGate = renameGate
        self.moveGate = moveGate
    }

    func moveTrack(
        id trackId: UUID,
        toFolder destinationFolderId: UUID,
        using fileBusyChecker: any TrackFileBusyChecking
    ) async throws -> TrackFileMutationOutcome {
        await events.record("move")
        await moveGate.wait()
        return .confirmed
    }

    func renameTrack(
        id trackId: UUID,
        to newFileName: String,
        using fileBusyChecker: any TrackFileBusyChecking
    ) async throws -> TrackFileMutationOutcome {
        await events.record("rename:\(newFileName)")
        await renameGate.wait()
        await urlResolver.replaceCurrentURL(
            URL(fileURLWithPath: "/tmp/track-file-operation-tests/\(newFileName)")
        )
        return .confirmed
    }
}

/// Controlled resolver подтверждает, какой URL был прочитан до физической мутации.
private actor TrackFileURLResolverSpy: TrackFileURLResolving {
    private var currentURL: URL
    private var resolvedURLs: [URL] = []

    init(initialURL: URL) {
        currentURL = initialURL
    }

    func url(forTrackId trackId: UUID) -> URL? {
        resolvedURLs.append(currentURL)
        return currentURL
    }

    func replaceCurrentURL(_ url: URL) {
        currentURL = url
    }

    func resolvedFileNames() -> [String] {
        resolvedURLs.map(\.lastPathComponent)
    }
}

/// Controlled post-update удерживает completion, чтобы проверить границу ownership после физической мутации.
private actor TrackPostUpdateHandlerSpy: TrackPostUpdateHandling {
    private let events: TrackFileOperationEventLog
    private let updateGate: TrackFileOperationGate

    init(
        events: TrackFileOperationEventLog,
        updateGate: TrackFileOperationGate
    ) {
        self.events = events
        self.updateGate = updateGate
    }

    func handleTrackUpdate(
        forTrackId trackId: UUID,
        reason: TrackUpdateReason,
        changedFields: Set<TrackChangedField>,
        previousURL: URL?
    ) async throws -> TrackUpdateEvent {
        await events.record("post")
        await updateGate.wait()
        return makeConfirmedTrackUpdateEvent(trackId: trackId)
    }

    func prepareTrackUpdate(
        forTrackId trackId: UUID,
        reason: TrackUpdateReason,
        changedFields: Set<TrackChangedField>,
        previousURL: URL?
    ) async throws -> TrackUpdateEvent {
        await events.record("prepare")
        return makeConfirmedTrackUpdateEvent(trackId: trackId)
    }

    func publishTrackBatchUpdateEvents(_ updateEvents: [TrackUpdateEvent]) async {
        await events.record("batch publish")
    }
}

/// Имитирует отсутствие финального snapshot после уже выполненной файловой операции.
private actor TrackPostUpdateFailureSpy: TrackPostUpdateHandling {
    func handleTrackUpdate(
        forTrackId trackId: UUID,
        reason: TrackUpdateReason,
        changedFields: Set<TrackChangedField>,
        previousURL: URL?
    ) async throws -> TrackUpdateEvent {
        throw AppError.trackUpdateConfirmationFailed
    }

    func prepareTrackUpdate(
        forTrackId trackId: UUID,
        reason: TrackUpdateReason,
        changedFields: Set<TrackChangedField>,
        previousURL: URL?
    ) async throws -> TrackUpdateEvent {
        throw AppError.trackUpdateConfirmationFailed
    }

    func publishTrackBatchUpdateEvents(_ updateEvents: [TrackUpdateEvent]) async {}
}

/// Возвращает заранее подготовленный результат физического копирования без MediaPlayer и файловой системы.
private struct PurchasedITunesTrackCopyStub: PurchasedITunesTrackCopying {
    let result: PurchasedITunesTrackCopyResult

    func copy(
        _ track: PurchasedITunesPlayableTrack,
        toFolder destinationFolderId: UUID
    ) async throws -> PurchasedITunesTrackCopyResult {
        result
    }
}

/// Возвращает контролируемый sync outcome без изменения production реестров.
private struct LibraryRootSyncStub: LibraryRootSyncing {
    let outcome: LibrarySyncOutcome

    func syncRootFolder(
        rootFolderId: UUID,
        rootURL: URL,
        mode: LibrarySyncModule.SyncMode,
        logsDatabaseDiagnostics: Bool
    ) async throws -> LibrarySyncOutcome {
        outcome
    }
}

/// Собирает минимальный подтверждённый snapshot для проверки ownership без production metadata reader.
private func makeConfirmedTrackUpdateEvent(trackId: UUID) -> TrackUpdateEvent {
    let snapshot = TrackRuntimeSnapshot(
        trackId: trackId,
        fileName: "Track.mp3",
        isAvailable: true,
        technicalMetadata: TrackTechnicalMetadata(
            fileSizeBytes: nil,
            fileFormat: "MP3",
            bitrateBitsPerSecond: nil
        ),
        title: "Track",
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
        duration: nil,
        artworkData: nil,
        artworkSourceIdentifier: nil,
        updatedAt: Date(timeIntervalSince1970: 0)
    )
    return TrackUpdateEvent(
        trackId: trackId,
        reason: .metadataUpdated,
        changedFields: [.title],
        snapshot: snapshot
    )
}

/// Controlled tag writer подтверждает, что запись содержимого файла использует тот же owner.
private actor TrackTagsWriterSpy: TagsWriter {
    private let events: TrackFileOperationEventLog
    private let writeGate: TrackFileOperationGate

    init(
        events: TrackFileOperationEventLog,
        writeGate: TrackFileOperationGate
    ) {
        self.events = events
        self.writeGate = writeGate
    }

    func writeTags(
        to url: URL,
        patch: TagWritePatch
    ) async throws {
        await events.record("tag write")
        await writeGate.wait()
    }
}

/// Move-result не зависит от production TrackRegistry в controlled integration tests.
private struct TrackFolderNameResolverStub: TrackFolderNameResolving {
    func folderName(forFolderId folderId: UUID) async -> String? {
        "Destination"
    }
}

/// File manager получает существующую capability, но тесту не нужен PlayerManager.
private final class TrackFileBusyCheckerStub: TrackFileBusyChecking {
    func isTrackFileBusy(trackId: UUID) -> Bool {
        false
    }
}

/// Отличает ожидаемую controlled failure от ошибки тестовой инфраструктуры.
private enum TrackFileOperationTestError: Error {
    case failed
}
