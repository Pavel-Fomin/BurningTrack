//
//  BatchTagEditFlowTests.swift
//  TrackList
//
//  Focused-проверки feature-local flow массового редактирования тегов.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation
import XCTest
@testable import TrackList

/// Проверяет Batch Tag Edit через явные feature-local зависимости без SheetManager.shared.
@MainActor
final class BatchTagEditFlowTests: XCTestCase {

    func testLoadingStateUsesImmutableSheetRoutePayload() {
        let pendingAction = makePendingAction(trackIDs: [UUID(), UUID()])
        let viewModel = makeViewModel(pendingAction: pendingAction)

        XCTAssertEqual(viewModel.state.phase, .loadingMetadata)
        XCTAssertEqual(viewModel.state.artwork.summary.selectedCount, 2)
    }

    func testAppearedLoadsMetadataAndEntersEditing() async {
        let flow = makeFlow()
        let viewModel = makeViewModel(loader: BatchTagMetadataLoaderSpy(flow: flow))

        viewModel.send(.appeared)
        await completeScheduledTask()

        XCTAssertEqual(viewModel.state.phase, .editing)
        XCTAssertEqual(viewModel.state.displayedFields.count, EditableTrackField.allCases.count)
    }

    func testRepeatedAppearedStartsOnlyOneInitialLoad() async {
        let loader = BatchTagMetadataLoaderSpy(flow: makeFlow())
        let viewModel = makeViewModel(loader: loader)

        viewModel.send(.appeared)
        viewModel.send(.appeared)
        await completeScheduledTask()

        XCTAssertEqual(loader.loadCount, 1)
    }

    func testGroupValueChangedToOriginalRestoresKeepIntent() async {
        let viewModel = await makeLoadedViewModel()

        viewModel.send(.fieldValueChanged(field: .title, value: "Original Title"))

        XCTAssertFalse(viewModel.state.canSave)
    }

    func testGroupEmptyValueCreatesClearIntent() async {
        let viewModel = await makeLoadedViewModel()

        viewModel.send(.fieldValueChanged(field: .title, value: "   "))

        XCTAssertTrue(viewModel.state.canSave)
    }

    func testGroupNonemptyValueCreatesSetIntent() async {
        let viewModel = await makeLoadedViewModel()

        viewModel.send(.fieldValueChanged(field: .artist, value: "New Artist"))

        XCTAssertTrue(viewModel.state.canSave)
        XCTAssertEqual(displayedValue(.artist, in: viewModel), "New Artist")
    }

    func testSelectedTrackShowsPerTrackFields() async {
        let flow = makeFlow()
        let viewModel = await makeLoadedViewModel(flow: flow)
        let trackId = flow.tracks[0].trackId

        viewModel.send(.artworkTargetSelected(.track(trackId)))

        XCTAssertEqual(displayedValue(.title, in: viewModel), "Original Title")
    }

    func testPerTrackOverrideChangesOnlySelectedPresentation() async {
        let flow = makeFlow()
        let viewModel = await makeLoadedViewModel(flow: flow)
        let trackId = flow.tracks[0].trackId

        viewModel.send(.artworkTargetSelected(.track(trackId)))
        viewModel.send(.fieldValueChanged(field: .title, value: "Track Title"))

        XCTAssertEqual(displayedValue(.title, in: viewModel), "Track Title")
        XCTAssertTrue(viewModel.state.canSave)
    }

    func testPerTrackReturnToOriginalRemovesOverride() async {
        let flow = makeFlow()
        let viewModel = await makeLoadedViewModel(flow: flow)
        let trackId = flow.tracks[0].trackId

        viewModel.send(.artworkTargetSelected(.track(trackId)))
        viewModel.send(.fieldValueChanged(field: .title, value: "Track Title"))
        viewModel.send(.fieldValueChanged(field: .title, value: "Original Title"))

        XCTAssertFalse(viewModel.state.canSave)
    }

    func testArtworkRemoveUpdatesAllCardsForSummaryTarget() async {
        let viewModel = await makeLoadedViewModel()

        viewModel.send(.artworkRemoveTapped(target: .summary))

        XCTAssertTrue(viewModel.state.cardsAreWithoutArtwork)
        XCTAssertTrue(viewModel.state.canSave)
    }

    func testArtworkReplaceUsesPreparedDataAndEnablesSave() async {
        let replacement = Data([7, 8, 9])
        let viewModel = await makeLoadedViewModel(preparer: BatchTagArtworkPreparerSpy(result: replacement))

        viewModel.send(.artworkReplacementSelected(target: .summary, data: Data([1])))
        await completeScheduledTask()

        XCTAssertTrue(viewModel.state.artwork.cards.allSatisfy { $0.hasArtwork })
        XCTAssertTrue(viewModel.state.canSave)
    }

    func testArtworkReplacementFailureLeavesDraftUnchanged() async {
        let viewModel = await makeLoadedViewModel(preparer: BatchTagArtworkPreparerSpy(shouldFail: true))

        viewModel.send(.artworkReplacementSelected(target: .summary, data: Data([1])))
        await completeScheduledTask()

        XCTAssertFalse(viewModel.state.canSave)
        XCTAssertNil(viewModel.state.artwork.preparationProgress)
    }

    func testCompressionUsesReplacementAsCurrentArtworkSource() async {
        let flow = makeFlow()
        let compressor = BatchTagArtworkCompressorSpy(results: [.success(Data([4, 5]))])
        let viewModel = await makeLoadedViewModel(
            flow: flow,
            dataProvider: BatchTagArtworkDataProviderSpy(),
            compressor: compressor
        )
        let trackId = flow.tracks[0].trackId

        viewModel.send(.artworkReplacementSelected(target: .track(trackId), data: Data([1, 2, 3])))
        await completeScheduledTask()
        viewModel.send(.artworkCompressTapped(target: .track(trackId), option: .small))
        await completeScheduledTask()

        XCTAssertTrue(viewModel.state.canSave)
        XCTAssertFalse(viewModel.state.artwork.isCompressing)
    }

    func testCompressionKeepsOtherItemsAfterSingleFailure() async {
        let flow = makeFlow()
        let provider = BatchTagArtworkDataProviderSpy(dataByTrackID: Dictionary(
            uniqueKeysWithValues: flow.tracks.map { ($0.trackId, Data([1])) }
        ))
        let compressor = BatchTagArtworkCompressorSpy(
            results: [.failure, .success(Data([9]))]
        )
        let viewModel = await makeLoadedViewModel(
            flow: flow,
            dataProvider: provider,
            compressor: compressor
        )

        viewModel.send(.artworkCompressTapped(target: .summary, option: .small))
        await completeScheduledTask()

        XCTAssertNotNil(viewModel.state.artwork.compressionFailureText)
        XCTAssertTrue(viewModel.state.canSave)
    }

    func testCompressionWithoutArtworkReportsFailureWithoutSaving() async {
        let viewModel = await makeLoadedViewModel(dataProvider: BatchTagArtworkDataProviderSpy())

        viewModel.send(.artworkCompressTapped(target: .summary, option: .small))

        XCTAssertNotNil(viewModel.state.artwork.compressionFailureText)
        XCTAssertFalse(viewModel.state.artwork.isCompressing)
    }

    func testPresenterCreatesOriginalArtworkRequestWithoutLeafDependencies() {
        let flow = makeFlow()
        let presenter = BatchTagEditPresenter(toastPresenter: BatchTagToastSpy())

        let state = presenter.makeState(from: flow)

        XCTAssertNotNil(state.artwork.cards[0].artworkRequest)
    }

    func testSaveSuccessPreservesToastContract() async {
        let toast = BatchTagToastSpy()
        let executor = BatchTagSaveExecutorSpy(
            result: BatchTagEditSaveResult(
                confirmed: [makeConfirmedSaveSuccess(trackId: UUID())],
                failures: []
            )
        )
        let viewModel = await makeLoadedViewModel(toast: toast, saveExecutor: executor)

        viewModel.send(.fieldValueChanged(field: .title, value: "Updated"))
        viewModel.send(.saveTapped)
        await completeScheduledTask()

        XCTAssertTrue(toast.events.contains { event in
            if case .batchTagsUpdated = event { return true }
            return false
        })
    }

    func testPartialSaveKeepsFailureSummaryAndReloadsFlow() async {
        let flow = makeFlow()
        let toast = BatchTagToastSpy()
        let executor = BatchTagSaveExecutorSpy(
            result: BatchTagEditSaveResult(
                confirmed: [makeConfirmedSaveSuccess(trackId: flow.tracks[0].trackId)],
                failures: [
                    BatchTagEditSaveFailure(
                        trackId: flow.tracks[1].trackId,
                        failure: MutationFailure(
                            stage: .confirm,
                            appError: .trackUpdateConfirmationFailed,
                            recovery: .confirmationMissing
                        )
                    )
                ]
            )
        )
        let loader = BatchTagMetadataLoaderSpy(flow: flow)
        let viewModel = await makeLoadedViewModel(
            flow: flow,
            loader: loader,
            toast: toast,
            saveExecutor: executor
        )

        viewModel.send(.fieldValueChanged(field: .title, value: "Updated"))
        viewModel.send(.saveTapped)
        await completeScheduledTask()

        XCTAssertEqual(viewModel.state.saveSummary?.confirmedCount, 1)
        XCTAssertEqual(viewModel.state.saveSummary?.failures.map(\.trackId), [flow.tracks[1].trackId])
        XCTAssertEqual(
            viewModel.state.saveSummary?.failures.first?.message,
            String(localized: "batchMutation.fileChangedDataNotUpdated")
        )
        XCTAssertFalse(toast.events.contains { event in
            if case .batchTagsPartiallyUpdated = event { return true }
            return false
        })
        XCTAssertGreaterThanOrEqual(loader.loadCount, 2)
    }

    func testMixedSaveKeepsConfirmedAndBothFailureSemanticsInScreenState() async {
        let trackIDs = [UUID(), UUID(), UUID()]
        let flow = makeFlow(trackIDs: trackIDs)
        let executor = BatchTagSaveExecutorSpy(
            result: BatchTagEditSaveResult(
                confirmed: [makeConfirmedSaveSuccess(trackId: trackIDs[0])],
                failures: [
                    BatchTagEditSaveFailure(
                        trackId: trackIDs[1],
                        failure: MutationFailure(
                            stage: .perform,
                            appError: .tagWriteFailed,
                            recovery: .untouched
                        )
                    ),
                    BatchTagEditSaveFailure(
                        trackId: trackIDs[2],
                        failure: MutationFailure(
                            stage: .confirm,
                            appError: .trackUpdateConfirmationFailed,
                            recovery: .confirmationMissing
                        )
                    )
                ]
            )
        )
        let viewModel = await makeLoadedViewModel(flow: flow, saveExecutor: executor)

        viewModel.send(.fieldValueChanged(field: .title, value: "Updated"))
        viewModel.send(.saveTapped)
        await completeScheduledTask()

        XCTAssertEqual(viewModel.state.saveSummary?.confirmedCount, 1)
        XCTAssertEqual(viewModel.state.saveSummary?.failures.map(\.trackId), [trackIDs[1], trackIDs[2]])
        XCTAssertEqual(
            viewModel.state.saveSummary?.failures.map(\.message),
            [
                String(localized: "batchMutation.changeNotCompleted"),
                String(localized: "batchMutation.fileChangedDataNotUpdated")
            ]
        )
    }

    func testFullyFailedSaveKeepsFailureSummaryWithoutReload() async {
        let flow = makeFlow()
        let toast = BatchTagToastSpy()
        let executor = BatchTagSaveExecutorSpy(
            result: BatchTagEditSaveResult(
                confirmed: [],
                failures: [
                    BatchTagEditSaveFailure(
                        trackId: flow.tracks[0].trackId,
                        failure: MutationFailure(
                            stage: .perform,
                            appError: .tagWriteFailed,
                            recovery: .untouched
                        )
                    )
                ]
            )
        )
        let loader = BatchTagMetadataLoaderSpy(flow: flow)
        let viewModel = await makeLoadedViewModel(
            flow: flow,
            loader: loader,
            toast: toast,
            saveExecutor: executor
        )

        viewModel.send(.fieldValueChanged(field: .title, value: "Updated"))
        viewModel.send(.saveTapped)
        await completeScheduledTask()

        XCTAssertEqual(viewModel.state.saveSummary?.confirmedCount, 0)
        XCTAssertEqual(viewModel.state.saveSummary?.failures.map(\.trackId), [flow.tracks[0].trackId])
        XCTAssertEqual(
            viewModel.state.saveSummary?.failures.first?.message,
            String(localized: "batchMutation.changeNotCompleted")
        )
        XCTAssertFalse(toast.events.contains { event in
            if case .batchTagsUpdateFailed = event { return true }
            return false
        })
        XCTAssertEqual(loader.loadCount, 1)
    }

    func testReloadRetainsSelectedExistingTrackTarget() async {
        let flow = makeFlow()
        let executor = BatchTagSaveExecutorSpy(
            result: BatchTagEditSaveResult(
                confirmed: [makeConfirmedSaveSuccess(trackId: flow.tracks[0].trackId)],
                failures: []
            )
        )
        let viewModel = await makeLoadedViewModel(flow: flow, saveExecutor: executor)
        let selectedTrackID = flow.tracks[0].trackId

        viewModel.send(.artworkTargetSelected(.track(selectedTrackID)))
        viewModel.send(.fieldValueChanged(field: .title, value: "Updated"))
        viewModel.send(.saveTapped)
        await completeScheduledTask()

        XCTAssertEqual(viewModel.state.artwork.selectedTarget, .track(selectedTrackID))
    }

    func testReloadFallsBackToSummaryWhenSelectedTrackDisappears() async {
        let originalFlow = makeFlow()
        let reloadedFlow = makeFlow(trackIDs: [originalFlow.tracks[1].trackId])
        let loader = BatchTagMetadataLoaderSpy(flows: [originalFlow, reloadedFlow])
        let executor = BatchTagSaveExecutorSpy(
            result: BatchTagEditSaveResult(
                confirmed: [makeConfirmedSaveSuccess(trackId: originalFlow.tracks[0].trackId)],
                failures: []
            )
        )
        let viewModel = await makeLoadedViewModel(
            flow: originalFlow,
            loader: loader,
            saveExecutor: executor
        )

        viewModel.send(.artworkTargetSelected(.track(originalFlow.tracks[0].trackId)))
        viewModel.send(.fieldValueChanged(field: .title, value: "Updated"))
        viewModel.send(.saveTapped)
        await completeScheduledTask()

        XCTAssertEqual(viewModel.state.artwork.selectedTarget, .summary)
    }

    func testCloseRoutesThroughFeatureLocalRouter() {
        let router = BatchTagRouterSpy()
        let viewModel = makeViewModel(router: router)

        viewModel.send(.closeTapped)

        XCTAssertEqual(router.closeCount, 1)
    }

    func testSheetDisappearanceIgnoresLateMetadataResult() async {
        let loader = BatchTagDelayedMetadataLoaderSpy(flow: makeFlow())
        let viewModel = makeViewModel(loader: loader)

        viewModel.send(.appeared)
        viewModel.send(.sheetDisappeared)
        await completeScheduledTask()

        XCTAssertEqual(viewModel.state.phase, .loadingMetadata)
    }

    private func makeLoadedViewModel(
        flow: BatchTagEditFlow? = nil,
        loader: BatchTagMetadataLoaderSpy? = nil,
        toast: BatchTagToastSpy? = nil,
        saveExecutor: BatchTagSaveExecutorSpy? = nil,
        dataProvider: BatchTagArtworkDataProviderSpy? = nil,
        preparer: BatchTagArtworkPreparerSpy? = nil,
        compressor: BatchTagArtworkCompressorSpy? = nil
    ) async -> BatchTagEditViewModel {
        let resolvedFlow = flow ?? makeFlow()
        let resolvedLoader = loader ?? BatchTagMetadataLoaderSpy(flow: resolvedFlow)
        let viewModel = makeViewModel(
            pendingAction: resolvedFlow.pendingAction
                ?? makePendingAction(trackIDs: resolvedFlow.tracks.map(\.trackId)),
            loader: resolvedLoader,
            toast: toast,
            saveExecutor: saveExecutor,
            dataProvider: dataProvider,
            preparer: preparer,
            compressor: compressor
        )
        viewModel.send(.appeared)
        await completeScheduledTask()
        return viewModel
    }

    private func makeViewModel(
        pendingAction: PendingBulkTrackAction? = nil,
        loader: (any BatchTagEditMetadataLoading)? = nil,
        toast: BatchTagToastSpy? = nil,
        saveExecutor: (any BatchTagEditSaveExecuting)? = nil,
        dataProvider: (any BatchTagArtworkDataProviding)? = nil,
        preparer: (any BatchTagArtworkPreparing)? = nil,
        compressor: (any BatchTagArtworkCompressing)? = nil,
        router: BatchTagRouterSpy? = nil
    ) -> BatchTagEditViewModel {
        let resolvedPendingAction = pendingAction ?? makePendingAction(trackIDs: [UUID(), UUID()])
        let resolvedLoader = loader ?? BatchTagMetadataLoaderSpy(flow: makeFlow())
        let resolvedToast = toast ?? BatchTagToastSpy()
        let resolvedSaveExecutor = saveExecutor ?? BatchTagSaveExecutorSpy()
        let resolvedDataProvider = dataProvider ?? BatchTagArtworkDataProviderSpy()
        let resolvedPreparer = preparer ?? BatchTagArtworkPreparerSpy()
        let resolvedCompressor = compressor ?? BatchTagArtworkCompressorSpy()
        let resolvedRouter = router ?? BatchTagRouterSpy()
        let presenter = BatchTagEditPresenter(toastPresenter: resolvedToast)
        let handler = BatchTagEditActionHandler(
            metadataLoader: resolvedLoader,
            saveExecutor: resolvedSaveExecutor,
            artworkDataProvider: resolvedDataProvider,
            artworkPreparer: resolvedPreparer,
            artworkCompressor: resolvedCompressor,
            presenter: presenter,
            router: resolvedRouter
        )
        return BatchTagEditViewModel(
            sheetData: BatchTagEditSheetData(id: UUID(), pendingAction: resolvedPendingAction),
            presenter: presenter,
            actionHandler: handler
        )
    }

    private func makePendingAction(trackIDs: [UUID]) -> PendingBulkTrackAction {
        PendingBulkTrackAction(action: .editTags, trackIDs: trackIDs)
    }

    private func makeFlow(trackIDs: [UUID] = [UUID(), UUID()]) -> BatchTagEditFlow {
        let tracks = trackIDs.map { trackId in
            BatchTagEditTrack(
                trackId: trackId,
                fileName: "Track \(trackId.uuidString).flac",
                values: baselineValues(),
                hasArtwork: true
            )
        }
        let artworkData = Data([1, 2, 3])
        return BatchTagEditFlow(
            pendingAction: makePendingAction(trackIDs: trackIDs),
            phase: .editing,
            tracks: tracks,
            fields: EditableTrackField.allCases.map { field in
                let value = baselineValues()[field] ?? ""
                return BatchTagFieldEditState(
                    field: field,
                    action: .keep,
                    value: value,
                    summary: value.isEmpty ? .empty : .same(value)
                )
            },
            trackFieldOverrides: [:],
            artwork: BatchTagArtworkEditState(
                summary: .same,
                previewSummary: BatchTagArtworkPreviewSummary(
                    selectedCount: trackIDs.count,
                    artworkCount: trackIDs.count,
                    missingArtworkCount: 0,
                    totalArtworkSizeBytes: artworkData.count * trackIDs.count
                ),
                previewItems: trackIDs.map { trackId in
                    BatchTagArtworkPreviewItem(
                        id: trackId,
                        trackId: trackId,
                        title: "Track",
                        hasArtwork: true,
                        artworkRevision: Date(timeIntervalSince1970: 0),
                        artworkSizeBytes: artworkData.count,
                        originalArtworkRequest: ArtworkRequest(
                            trackId: trackId,
                            artworkData: artworkData,
                            purpose: .batchTagPreview,
                            sourceIdentifier: .transient(revision: trackId)
                        )
                    )
                },
                selectedTarget: .summary
            )
        )
    }

    private func baselineValues() -> [EditableTrackField: String] {
        [
            .title: "Original Title",
            .artist: "Original Artist",
            .album: "Original Album",
            .genre: "Original Genre",
            .year: "2020",
            .publisher: "Original Label",
            .comment: "Original Comment"
        ]
    }

    private func displayedValue(_ field: EditableTrackField, in viewModel: BatchTagEditViewModel) -> String? {
        viewModel.state.displayedFields.first(where: { $0.field == field })?.value
    }

    private func completeScheduledTask() async {
        try? await Task.sleep(nanoseconds: 100_000_000)
        for _ in 0..<8 {
            await Task.yield()
        }
    }
}

private extension BatchTagEditScreenState {
    /// Упрощает проверку summary-удаления без раскрытия draft в тестах.
    var cardsAreWithoutArtwork: Bool {
        artwork.cards.allSatisfy { !$0.hasArtwork && $0.artworkRequest == nil }
    }
}

@MainActor
private final class BatchTagMetadataLoaderSpy: BatchTagEditMetadataLoading {
    private var flows: [BatchTagEditFlow]
    private(set) var loadCount = 0

    init(flow: BatchTagEditFlow) {
        flows = [flow]
    }

    init(flows: [BatchTagEditFlow]) {
        self.flows = flows
    }

    func loadFlow(pendingAction: PendingBulkTrackAction) async -> BatchTagEditFlow {
        loadCount += 1
        return flows.isEmpty ? BatchTagEditFlow(
            pendingAction: pendingAction,
            phase: .editing,
            tracks: [],
            fields: [],
            trackFieldOverrides: [:],
            artwork: BatchTagArtworkEditState(
                summary: .none,
                previewSummary: BatchTagArtworkPreviewSummary(selectedCount: 0, artworkCount: 0, missingArtworkCount: 0),
                previewItems: [],
                selectedTarget: .summary
            )
        ) : flows[min(loadCount - 1, flows.count - 1)]
    }
}

@MainActor
private final class BatchTagDelayedMetadataLoaderSpy: BatchTagEditMetadataLoading {
    private let flow: BatchTagEditFlow

    init(flow: BatchTagEditFlow) {
        self.flow = flow
    }

    func loadFlow(pendingAction: PendingBulkTrackAction) async -> BatchTagEditFlow {
        await Task.yield()
        return flow
    }
}

/// MainActor-double соответствует единой точке запуска batch-команды.
@MainActor
private final class BatchTagSaveExecutorSpy: BatchTagEditSaveExecuting {
    private let result: BatchTagEditSaveResult

    init(result: BatchTagEditSaveResult = BatchTagEditSaveResult(confirmed: [], failures: [])) {
        self.result = result
    }

    func execute(plan: BatchTagEditSavePlan) async -> BatchTagEditSaveResult {
        result
    }
}

/// Создаёт receipt, который batch использует только для подтверждённого сохранения одного трека.
private func makeConfirmedSaveSuccess(trackId: UUID) -> BatchTagEditSaveSuccess {
    BatchTagEditSaveSuccess(
        trackId: trackId,
        snapshot: TrackRuntimeSnapshot(
            trackId: trackId,
            fileName: "Track.flac",
            isAvailable: true,
            technicalMetadata: TrackTechnicalMetadata(
                fileSizeBytes: nil,
                fileFormat: "FLAC",
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
    )
}

@MainActor
private final class BatchTagArtworkDataProviderSpy: BatchTagArtworkDataProviding {
    private let dataByTrackID: [UUID: Data]

    init(dataByTrackID: [UUID: Data] = [:]) {
        self.dataByTrackID = dataByTrackID
    }

    func snapshot(forTrackId trackId: UUID) -> TrackRuntimeSnapshot? {
        guard let artworkData = dataByTrackID[trackId] else { return nil }
        return TrackRuntimeSnapshot(
            trackId: trackId,
            fileName: "Track.flac",
            isAvailable: true,
            technicalMetadata: TrackTechnicalMetadata(fileSizeBytes: nil, fileFormat: nil, bitrateBitsPerSecond: nil),
            title: nil,
            artist: nil,
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
            artworkData: artworkData,
            artworkSourceIdentifier: .transient(revision: trackId),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}

private struct BatchTagArtworkPreparerSpy: BatchTagArtworkPreparing {
    let result: Data?
    let shouldFail: Bool

    init(result: Data? = nil, shouldFail: Bool = false) {
        self.result = result
        self.shouldFail = shouldFail
    }

    func prepareReplacementArtwork(data: Data) async throws -> Data {
        if shouldFail {
            throw BatchTagTestError.failed
        }
        return result ?? data
    }
}

private actor BatchTagArtworkCompressorSpy: BatchTagArtworkCompressing {
    private var results: [BatchTagCompressionResult]

    init(results: [BatchTagCompressionResult] = []) {
        self.results = results
    }

    func compressArtwork(data: Data, option: BatchArtworkCompressionOption) async throws -> Data {
        let result = results.isEmpty ? .success(data) : results.removeFirst()
        switch result {
        case .success(let compressedData):
            return compressedData
        case .failure:
            throw BatchTagTestError.failed
        }
    }
}

private enum BatchTagCompressionResult {
    case success(Data)
    case failure
}

@MainActor
private final class BatchTagToastSpy: ToastPresenting {
    private(set) var events: [ToastEvent] = []

    func handle(_ event: ToastEvent, duration: TimeInterval) {
        events.append(event)
    }

    func handle(_ error: AppError) {}
}

@MainActor
private final class BatchTagRouterSpy: BatchTagEditRouting {
    private(set) var closeCount = 0

    func presentBatchTagEdit(pendingAction: PendingBulkTrackAction) {}

    func dismissBatchTagEdit(_ routeID: UUID) {
        closeCount += 1
    }
}

private enum BatchTagTestError: Error {
    case failed
}
