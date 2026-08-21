//
//  BatchFilenameRenameFlowTests.swift
//  TrackList
//
//  Изолированные проверки feature-local сценария массового переименования файлов.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation
import XCTest
@testable import TrackList

/// Проверяет Batch Filename Rename через явные feature-local зависимости без SheetManager.shared.
@MainActor
final class BatchFilenameRenameFlowTests: XCTestCase {
    func testInitialStateShowsImmutableSeedNamesBeforeMetadataLoading() {
        let seeds = makeSeeds()
        let viewModel = makeViewModel(seeds: seeds)

        XCTAssertTrue(viewModel.state.isLoadingMetadata)
        XCTAssertTrue(viewModel.state.isDismissDisabled)
        XCTAssertEqual(viewModel.state.rows.map(\.fileName), seeds.map(\.currentFileName))
    }

    func testAppearedLoadsMetadataOnlyOnceAndPublishesValidationErrors() async {
        let seeds = makeSeeds()
        let preparedTracks = [
            track(from: seeds[0], artist: "Artist", title: "Title"),
            track(from: seeds[1], artist: nil, title: "Title"),
            track(from: seeds[2], artist: nil, title: nil)
        ]
        let loader = BatchFilenameRenameMetadataLoaderSpy(tracks: preparedTracks)
        let viewModel = makeViewModel(seeds: seeds, loader: loader)

        viewModel.send(.appeared)
        viewModel.send(.appeared)
        await completeScheduledTask()

        XCTAssertEqual(loader.loadCount, 1)
        XCTAssertFalse(viewModel.state.isLoadingMetadata)
        XCTAssertFalse(viewModel.state.isDismissDisabled)
        XCTAssertEqual(viewModel.state.rows.map(\.statusStyle), [.neutral, .error, .error])
    }

    func testPlanBuilderPreservesExtensionAndMakesNamesUniqueWithinFolderOnly() {
        let builder = BatchFilenameRenamePlanBuilder()
        let tracks = [
            BatchFilenameRenameTrack(
                seed: BatchFilenameRenameTrackSeed(
                    trackId: UUID(),
                    folderPath: "/Music/A",
                    currentFileName: "One.flac",
                    artist: "Artist",
                    title: "Title"
                )
            ),
            BatchFilenameRenameTrack(
                seed: BatchFilenameRenameTrackSeed(
                    trackId: UUID(),
                    folderPath: "/Music/A",
                    currentFileName: "Two.flac",
                    artist: "Artist",
                    title: "Title"
                )
            ),
            BatchFilenameRenameTrack(
                seed: BatchFilenameRenameTrackSeed(
                    trackId: UUID(),
                    folderPath: "/Music/B",
                    currentFileName: "Three.flac",
                    artist: "Artist",
                    title: "Title"
                )
            )
        ]

        let items = builder.makePlan(
            strategy: .artistTitle,
            tracks: tracks,
            preserving: []
        )

        XCTAssertEqual(
            items.map(\.targetFileName),
            ["Artist - Title.flac", "Artist - Title 1.flac", "Artist - Title.flac"]
        )
    }

    func testPlanBuilderPreservesSpecificMetadataAndApplyFailureStatuses() {
        let builder = BatchFilenameRenamePlanBuilder()
        let seeds = makeSeeds()
        let metadataItems = builder.makeMetadataValidationItems(
            for: [
                track(from: seeds[0], artist: nil, title: "Title"),
                track(from: seeds[1], artist: "Artist", title: nil),
                track(from: seeds[2], artist: nil, title: nil)
            ]
        )

        XCTAssertEqual(
            metadataItems.map(\.status),
            [.missingArtist, .missingTitle, .missingArtistAndTitle]
        )

        let readyItems = builder.makePlan(
            strategy: .artistTitle,
            tracks: seeds.map { track(from: $0, artist: "Artist", title: "Title") },
            preserving: []
        )
        let result = BatchFilenameRenameResult(
            succeeded: [],
            failed: [
                BatchFilenameRenameFailure(
                    trackId: readyItems[0].trackId,
                    targetFileName: readyItems[0].targetFileName,
                    error: LibraryFileError.trackIsPlaying
                ),
                BatchFilenameRenameFailure(
                    trackId: readyItems[1].trackId,
                    targetFileName: readyItems[1].targetFileName,
                    error: LibraryFileError.sourceURLUnavailable
                ),
                BatchFilenameRenameFailure(
                    trackId: readyItems[2].trackId,
                    targetFileName: readyItems[2].targetFileName,
                    error: LibraryFileError.moveFailed(
                        underlying: NSError(domain: "test", code: 1)
                    )
                )
            ]
        )

        XCTAssertEqual(
            builder.applying(result, to: readyItems).map(\.status),
            [.trackIsPlaying, .fileAccessDenied, .applyFailed]
        )
    }

    func testStrategySelectionRebuildsPreviewAndRemoveChangesOnlyCurrentSession() async {
        let seeds = makeSeeds().prefix(2).map { $0 }
        let loader = BatchFilenameRenameMetadataLoaderSpy(
            tracks: [
                track(from: seeds[0], artist: "Artist", title: "Title"),
                track(from: seeds[1], artist: "Second", title: "Track")
            ]
        )
        let viewModel = makeViewModel(seeds: seeds, loader: loader)

        viewModel.send(.appeared)
        await completeScheduledTask()
        viewModel.send(.strategySelected(.titleArtist))

        XCTAssertEqual(
            viewModel.state.selectedStrategyTitle,
            FileRenamePresentationText.strategyTitle(for: FilenameRenameStrategy.titleArtist)
        )
        XCTAssertEqual(
            viewModel.state.rows.map(\.fileName),
            ["Title - Artist.flac", "Track - Second.mp3"]
        )

        viewModel.send(.removeTrack(seeds[0].trackId))

        XCTAssertEqual(viewModel.state.rows.map(\.fileName), ["Track - Second.mp3"])
        XCTAssertTrue(viewModel.state.canRemoveTracks)
    }

    func testApplySendsOnlyReadyCommandsAndPreservesPartialResultStatuses() async {
        let seeds = makeSeeds()
        let loader = BatchFilenameRenameMetadataLoaderSpy(
            tracks: [
                track(from: seeds[0], artist: "Artist", title: "Title"),
                track(from: seeds[1], artist: nil, title: "Title"),
                track(from: seeds[2], artist: "Third", title: "Track")
            ]
        )
        let executor = BatchFilenameRenameExecutorSpy()
        executor.setResult(
            BatchFilenameRenameResult(
                succeeded: [
                    BatchFilenameRenameSuccess(
                        trackId: seeds[0].trackId,
                        oldFileName: seeds[0].currentFileName,
                        newFileName: "Artist - Title.flac"
                    )
                ],
                failed: [
                    BatchFilenameRenameFailure(
                        trackId: seeds[2].trackId,
                        targetFileName: "Third - Track.m4a",
                        error: LibraryFileError.trackIsPlaying
                    )
                ]
            )
        )
        let viewModel = makeViewModel(seeds: seeds, loader: loader, executor: executor)

        viewModel.send(.appeared)
        await completeScheduledTask()
        viewModel.send(.strategySelected(.artistTitle))
        viewModel.send(.renameTapped)
        await completeScheduledTask()

        let commands = executor.commands
        XCTAssertEqual(commands.map(\.trackId), [seeds[0].trackId, seeds[2].trackId])
        XCTAssertEqual(viewModel.state.rows.map(\.statusStyle), [.success, .error, .error])
        XCTAssertFalse(viewModel.state.isApplyingRename)
    }

    func testBusyApplyDoesNotStartSecondOperationOrRetryAutomatically() async {
        let seeds = makeSeeds().prefix(1).map { $0 }
        let loader = BatchFilenameRenameMetadataLoaderSpy(
            tracks: [track(from: seeds[0], artist: "Artist", title: "Title")]
        )
        let executor = BatchFilenameRenameExecutorSpy(delayNanoseconds: 80_000_000)
        let viewModel = makeViewModel(seeds: seeds, loader: loader, executor: executor)

        viewModel.send(.appeared)
        await completeScheduledTask()
        viewModel.send(.strategySelected(.artistTitle))
        viewModel.send(.renameTapped)
        viewModel.send(.renameTapped)
        await completeScheduledTask()

        let callCount = executor.callCount
        let commandCount = executor.commands.count

        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(commandCount, 1)
    }

    func testLateMetadataCompletionAfterSheetDisappearedDoesNotChangeClosedSession() async {
        let seeds = makeSeeds().prefix(1).map { $0 }
        let loader = BatchFilenameRenameMetadataLoaderSpy(
            tracks: [track(from: seeds[0], artist: "Artist", title: "Title")],
            delayNanoseconds: 100_000_000
        )
        let viewModel = makeViewModel(seeds: seeds, loader: loader)

        viewModel.send(.appeared)
        viewModel.send(.sheetDisappeared)
        await completeScheduledTask(delayNanoseconds: 140_000_000)

        XCTAssertTrue(viewModel.state.isLoadingMetadata)
        XCTAssertEqual(viewModel.state.rows.map(\.fileName), [seeds[0].currentFileName])
    }

    func testApplyCompletionAfterSheetDisappearedDoesNotMutateClosedSession() async {
        let seeds = makeSeeds().prefix(1).map { $0 }
        let loader = BatchFilenameRenameMetadataLoaderSpy(
            tracks: [track(from: seeds[0], artist: "Artist", title: "Title")]
        )
        let executor = BatchFilenameRenameExecutorSpy(delayNanoseconds: 100_000_000)
        let viewModel = makeViewModel(seeds: seeds, loader: loader, executor: executor)

        viewModel.send(.appeared)
        await completeScheduledTask()
        viewModel.send(.strategySelected(.artistTitle))
        viewModel.send(.renameTapped)
        viewModel.send(.sheetDisappeared)
        await completeScheduledTask(delayNanoseconds: 140_000_000)

        XCTAssertTrue(viewModel.state.isApplyingRename)
        XCTAssertEqual(viewModel.state.rows.first?.statusStyle, .neutral)
    }

    func testStaleMetadataFromClosedSessionDoesNotMutateNewSession() async {
        let firstSessionSeeds = makeSessionSeeds(fileName: "First.flac")
        let secondSessionSeeds = makeSessionSeeds(fileName: "Second.flac")
        let loader = BatchFilenameRenameDeferredMetadataLoaderSpy()
        let firstViewModel = makeViewModel(
            seeds: firstSessionSeeds,
            loader: loader
        )

        firstViewModel.send(.appeared)
        await waitForMetadataLoadCount(1, from: loader)
        firstViewModel.send(.sheetDisappeared)

        let secondViewModel = makeViewModel(
            seeds: secondSessionSeeds,
            loader: loader
        )
        secondViewModel.send(.appeared)
        await waitForMetadataLoadCount(2, from: loader)

        loader.completeLoad(
            at: 0,
            with: [track(from: firstSessionSeeds[0], artist: "First Artist", title: "First Title")]
        )
        await settleTaskQueue()

        XCTAssertTrue(secondViewModel.state.isLoadingMetadata)
        XCTAssertEqual(
            secondViewModel.state.rows.map(\.fileName),
            secondSessionSeeds.map(\.currentFileName)
        )

        loader.completeLoad(
            at: 1,
            with: [track(from: secondSessionSeeds[0], artist: nil, title: "Second Title")]
        )
        await settleTaskQueue()

        XCTAssertFalse(secondViewModel.state.isLoadingMetadata)
        XCTAssertEqual(secondViewModel.state.rows.map(\.statusStyle), [.error])
    }

    func testStaleApplyFromClosedSessionDoesNotMutateNewSession() async {
        let firstSessionSeeds = makeSessionSeeds(fileName: "First.flac")
        let secondSessionSeeds = makeSessionSeeds(fileName: "Second.flac")
        let firstLoader = BatchFilenameRenameMetadataLoaderSpy(
            tracks: [track(from: firstSessionSeeds[0], artist: "First Artist", title: "First Title")]
        )
        let executor = BatchFilenameRenameDeferredExecutorSpy()
        let firstViewModel = makeViewModel(
            seeds: firstSessionSeeds,
            loader: firstLoader,
            executor: executor
        )

        firstViewModel.send(.appeared)
        await settleTaskQueue()
        firstViewModel.send(.strategySelected(.artistTitle))
        firstViewModel.send(.renameTapped)
        await waitForExecutorCallCount(1, from: executor)
        firstViewModel.send(.sheetDisappeared)

        let secondViewModel = makeViewModel(seeds: secondSessionSeeds)
        secondViewModel.send(.appeared)
        await settleTaskQueue()
        let secondSessionState = secondViewModel.state

        executor.completeFirst(
            with: BatchFilenameRenameResult(
                succeeded: [
                    BatchFilenameRenameSuccess(
                        trackId: firstSessionSeeds[0].trackId,
                        oldFileName: firstSessionSeeds[0].currentFileName,
                        newFileName: "First Artist - First Title.flac"
                    )
                ],
                failed: []
            )
        )
        await settleTaskQueue()

        XCTAssertEqual(secondViewModel.state, secondSessionState)
    }

    private func makeViewModel(
        seeds: [BatchFilenameRenameTrackSeed]? = nil,
        loader: (any BatchFilenameRenameMetadataLoading)? = nil,
        executor: (any BatchFilenameRenameCommandExecuting)? = nil,
        router: BatchFilenameRenameRouterSpy? = nil
    ) -> BatchFilenameRenameViewModel {
        let resolvedSeeds = seeds ?? makeSeeds()
        let resolvedLoader = loader ?? BatchFilenameRenameMetadataLoaderSpy(
            tracks: resolvedSeeds.map(BatchFilenameRenameTrack.init(seed:))
        )
        let resolvedExecutor = executor ?? BatchFilenameRenameExecutorSpy()
        let resolvedRouter = router ?? BatchFilenameRenameRouterSpy()
        let handler = BatchFilenameRenameActionHandler(
            metadataLoader: resolvedLoader,
            planBuilder: BatchFilenameRenamePlanBuilder(),
            commandExecutor: resolvedExecutor,
            fileBusyChecker: BatchFilenameRenameBusyCheckerSpy(),
            router: resolvedRouter
        )

        return BatchFilenameRenameViewModel(
            sheetData: BatchFilenameRenameSheetData(
                id: UUID(),
                pendingAction: PendingBulkTrackAction(
                    action: .renameFiles,
                    trackIDs: resolvedSeeds.map(\.trackId)
                ),
                tracks: resolvedSeeds
            ),
            presenter: BatchFilenameRenamePresenter(),
            actionHandler: handler
        )
    }

    private func makeSeeds() -> [BatchFilenameRenameTrackSeed] {
        [
            BatchFilenameRenameTrackSeed(
                trackId: UUID(),
                folderPath: "/Music/A",
                currentFileName: "Original.flac",
                artist: "Library Artist",
                title: "Library Title"
            ),
            BatchFilenameRenameTrackSeed(
                trackId: UUID(),
                folderPath: "/Music/A",
                currentFileName: "Second.mp3",
                artist: "Second Artist",
                title: "Second Title"
            ),
            BatchFilenameRenameTrackSeed(
                trackId: UUID(),
                folderPath: "/Music/B",
                currentFileName: "Third.m4a",
                artist: "Third Artist",
                title: "Third Title"
            )
        ]
    }

    private func makeSessionSeeds(
        fileName: String
    ) -> [BatchFilenameRenameTrackSeed] {
        [
            BatchFilenameRenameTrackSeed(
                trackId: UUID(),
                folderPath: "/Music/Session",
                currentFileName: fileName,
                artist: "Fallback Artist",
                title: "Fallback Title"
            )
        ]
    }

    private func track(
        from seed: BatchFilenameRenameTrackSeed,
        artist: String?,
        title: String?
    ) -> BatchFilenameRenameTrack {
        BatchFilenameRenameTrack(
            seed: BatchFilenameRenameTrackSeed(
                trackId: seed.trackId,
                folderPath: seed.folderPath,
                currentFileName: seed.currentFileName,
                artist: artist,
                title: title
            )
        )
    }

    private func completeScheduledTask(
        delayNanoseconds: UInt64 = 20_000_000
    ) async {
        try? await Task.sleep(nanoseconds: delayNanoseconds)
        await settleTaskQueue()
    }

    /// Передаёт выполнение в ожидающие continuation без завязки новых проверок на таймер.
    private func settleTaskQueue() async {
        for _ in 0..<16 {
            await Task.yield()
        }
    }

    /// Ожидает controlled metadata continuation по наблюдаемому числу запущенных операций.
    private func waitForMetadataLoadCount(
        _ expectedCount: Int,
        from loader: BatchFilenameRenameDeferredMetadataLoaderSpy
    ) async {
        for _ in 0..<128 {
            if loader.loadCount >= expectedCount {
                return
            }
            await Task.yield()
        }

        XCTFail("Metadata operation did not reach expected count")
    }

    /// Ожидает controlled apply continuation по наблюдаемому числу writer-вызовов.
    private func waitForExecutorCallCount(
        _ expectedCount: Int,
        from executor: BatchFilenameRenameDeferredExecutorSpy
    ) async {
        for _ in 0..<128 {
            if executor.callCount >= expectedCount {
                return
            }
            await Task.yield()
        }

        XCTFail("Apply operation did not reach expected count")
    }
}

/// Возвращает контролируемые prepared tracks и фиксирует число metadata загрузок.
@MainActor
private final class BatchFilenameRenameMetadataLoaderSpy: BatchFilenameRenameMetadataLoading {
    private let tracks: [BatchFilenameRenameTrack]
    private let delayNanoseconds: UInt64
    private(set) var loadCount = 0

    init(
        tracks: [BatchFilenameRenameTrack],
        delayNanoseconds: UInt64 = 0
    ) {
        self.tracks = tracks
        self.delayNanoseconds = delayNanoseconds
    }

    func loadTracks(
        from seeds: [BatchFilenameRenameTrackSeed],
        progress: @escaping @MainActor (Int, Int) -> Void
    ) async -> [BatchFilenameRenameTrack] {
        loadCount += 1
        progress(0, seeds.count)
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        progress(seeds.count, seeds.count)
        return tracks
    }
}

/// Удерживает metadata operation до явного завершения конкретного feature-сеанса в тесте.
@MainActor
private final class BatchFilenameRenameDeferredMetadataLoaderSpy: BatchFilenameRenameMetadataLoading {
    private struct PendingLoad {
        let seeds: [BatchFilenameRenameTrackSeed]
        let progress: @MainActor (Int, Int) -> Void
        let continuation: CheckedContinuation<[BatchFilenameRenameTrack], Never>
    }

    private var pendingLoads: [PendingLoad?] = []
    private(set) var loadCount = 0

    func loadTracks(
        from seeds: [BatchFilenameRenameTrackSeed],
        progress: @escaping @MainActor (Int, Int) -> Void
    ) async -> [BatchFilenameRenameTrack] {
        loadCount += 1
        progress(0, seeds.count)

        return await withCheckedContinuation { continuation in
            pendingLoads.append(
                PendingLoad(
                    seeds: seeds,
                    progress: progress,
                    continuation: continuation
                )
            )
        }
    }

    /// Завершает выбранную continuation, чтобы старый и новый сеансы можно было завершить раздельно.
    func completeLoad(
        at index: Int,
        with tracks: [BatchFilenameRenameTrack]
    ) {
        guard pendingLoads.indices.contains(index),
              let pendingLoad = pendingLoads[index] else {
            XCTFail("Missing metadata continuation")
            return
        }

        pendingLoads[index] = nil
        pendingLoad.progress(pendingLoad.seeds.count, pendingLoad.seeds.count)
        pendingLoad.continuation.resume(returning: tracks)
    }
}

/// MainActor-double batch writer сохраняет только полученные команды, как production command flow.
@MainActor
private final class BatchFilenameRenameExecutorSpy: BatchFilenameRenameCommandExecuting {
    private var result = BatchFilenameRenameResult(succeeded: [], failed: [])
    private let delayNanoseconds: UInt64
    private(set) var commands: [BatchFilenameRenameCommand] = []
    private(set) var callCount = 0

    init(delayNanoseconds: UInt64 = 0) {
        self.delayNanoseconds = delayNanoseconds
    }

    func setResult(_ result: BatchFilenameRenameResult) {
        self.result = result
    }

    func renameTrackFilesBatch(
        _ commands: [BatchFilenameRenameCommand],
        using fileBusyChecker: any TrackFileBusyChecking,
        progress: (@MainActor (_ processed: Int, _ total: Int) -> Void)?
    ) async -> BatchFilenameRenameResult {
        self.commands = commands
        callCount += 1
        if let progress {
            progress(0, commands.count)
        }
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if let progress {
            progress(commands.count, commands.count)
        }
        return result
    }
}

/// Удерживает физическое rename на MainActor до явного завершения, не отменяя apply после закрытия UI.
@MainActor
private final class BatchFilenameRenameDeferredExecutorSpy: BatchFilenameRenameCommandExecuting {
    private var pendingContinuations: [CheckedContinuation<BatchFilenameRenameResult, Never>] = []
    private(set) var callCount = 0

    func renameTrackFilesBatch(
        _ commands: [BatchFilenameRenameCommand],
        using fileBusyChecker: any TrackFileBusyChecking,
        progress: (@MainActor (_ processed: Int, _ total: Int) -> Void)?
    ) async -> BatchFilenameRenameResult {
        callCount += 1
        if let progress {
            progress(0, commands.count)
        }

        return await withCheckedContinuation { continuation in
            pendingContinuations.append(continuation)
        }
    }

    /// Завершает первую физическую операцию после создания новой UI-сессии.
    func completeFirst(
        with result: BatchFilenameRenameResult
    ) {
        guard pendingContinuations.isEmpty == false else { return }
        let continuation = pendingContinuations.removeFirst()
        continuation.resume(returning: result)
    }
}

/// Проверка занятости не нужна для fake writer, но сохраняет production-контракт ActionHandler.
@MainActor
private final class BatchFilenameRenameBusyCheckerSpy: TrackFileBusyChecking {
    func isTrackFileBusy(trackId: UUID) -> Bool {
        false
    }
}

/// Запоминает routing close без обращения к общему SheetManager.
@MainActor
private final class BatchFilenameRenameRouterSpy: BatchFilenameRenameRouting {
    private(set) var closeCount = 0

    func presentBatchFilenameRename(
        pendingAction: PendingBulkTrackAction,
        tracks: [BatchFilenameRenameTrackSeed]
    ) {}

    func dismissBatchFilenameRename(_ routeID: UUID) {
        closeCount += 1
    }
}
