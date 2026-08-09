//
//  RenameTrackFileFlowTests.swift
//  TrackList
//
//  Focused-проверки экранного flow ручного переименования файла трека.
//
//  Created by Pavel Fomin on 08.08.2026.
//

import Foundation
import XCTest
@testable import TrackList

/// Проверяет Presenter, ViewModel и ActionHandler через явные зависимости feature-flow.
@MainActor
final class RenameTrackFileFlowTests: XCTestCase {

    func testInitialStateRemovesOriginalExtensionAndEnablesRename() {
        let (viewModel, _, _, _, _) = makeViewModel(
            currentFileName: "Original Name.flac"
        )

        XCTAssertEqual(viewModel.state.fileName, "Original Name")
        XCTAssertTrue(viewModel.state.isRenameEnabled)
        XCTAssertFalse(viewModel.state.isProcessing)
        XCTAssertNil(viewModel.state.alert)
    }

    func testWhitespaceFileNameDisablesRename() {
        let (viewModel, _, _, _, _) = makeViewModel()

        viewModel.send(.fileNameChanged(" \n "))

        XCTAssertFalse(viewModel.state.isRenameEnabled)
    }

    func testNormalFileNameEnablesRename() {
        let (viewModel, _, _, _, _) = makeViewModel()

        viewModel.send(.fileNameChanged("New Name"))

        XCTAssertEqual(viewModel.state.fileName, "New Name")
        XCTAssertTrue(viewModel.state.isRenameEnabled)
    }

    func testPresenterMapsFileAccessDeniedToStopPlaybackAlert() {
        let presenter = RenameTrackFilePresenter(
            toastPresenter: RenameTrackFileToastSpy()
        )

        XCTAssertEqual(
            presenter.present(.fileAccessDenied),
            .keepOpen(alert: .stopPlayback)
        )
    }

    func testPresenterMapsFileNameConflictToConflictAlert() {
        let presenter = RenameTrackFilePresenter(
            toastPresenter: RenameTrackFileToastSpy()
        )

        XCTAssertEqual(
            presenter.present(.fileAlreadyExists),
            .keepOpen(alert: .fileNameConflict)
        )
    }

    func testDismissAlertClearsTypedAlertState() async {
        let (viewModel, executor, _, _, _) = makeViewModel()
        await executor.setOutcomes([.appError(.fileAlreadyExists)])

        viewModel.send(.fileNameChanged("Conflict"))
        viewModel.send(.rename)
        await completeScheduledTask()
        XCTAssertEqual(viewModel.state.alert, .fileNameConflict)

        viewModel.send(.dismissAlert)

        XCTAssertNil(viewModel.state.alert)
        XCTAssertTrue(viewModel.state.isRenameEnabled)
    }

    func testRenameBuildsManualProposalAndInvokesSaveTrackEdits() async {
        let executor = RenameTrackFileExecutorSpy()
        let router = RenameTrackFileRouterSpy()
        let handler = makeActionHandler(
            executor: executor,
            router: router
        )
        let trackId = UUID()

        let presentation = await handler.rename(
            trackId: trackId,
            currentFileName: "Original.m4a",
            manualFileName: "  New Name  "
        )

        XCTAssertEqual(presentation, .close)
        let requests = await executor.requests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.trackId, trackId)
        XCTAssertEqual(requests.first?.newFileName, "New Name.m4a")
        XCTAssertTrue(requests.first?.fileChanged ?? false)
        XCTAssertFalse(requests.first?.tagsChanged ?? true)
        XCTAssertFalse(requests.first?.artworkChanged ?? true)
        XCTAssertEqual(router.closeCount, 1)
    }

    func testSuccessfulRenameShowsToastAndClosesFlow() async {
        let executor = RenameTrackFileExecutorSpy()
        let toast = RenameTrackFileToastSpy()
        let router = RenameTrackFileRouterSpy()
        let handler = makeActionHandler(
            executor: executor,
            toast: toast,
            router: router
        )

        _ = await handler.rename(
            trackId: UUID(),
            currentFileName: "Original.mp3",
            manualFileName: "Renamed"
        )

        XCTAssertEqual(toast.events, [.fileRenamed(newName: "Renamed.mp3")])
        XCTAssertEqual(router.closeCount, 1)
    }

    func testConfirmStopPlaybackReleasesFileAndRepeatsRename() async {
        let executor = RenameTrackFileExecutorSpy()
        await executor.setOutcomes([.appError(.fileAccessDenied), .success])
        let releaser = RenameTrackFilePlaybackReleaserSpy()
        let router = RenameTrackFileRouterSpy()
        let handler = makeActionHandler(
            executor: executor,
            playbackFileReleaser: releaser,
            router: router
        )

        let firstPresentation = await handler.rename(
            trackId: UUID(),
            currentFileName: "Original.wav",
            manualFileName: "Renamed"
        )
        let retryPresentation = await handler.confirmStopPlayback()

        XCTAssertEqual(firstPresentation, .keepOpen(alert: .stopPlayback))
        XCTAssertEqual(retryPresentation, .close)
        XCTAssertEqual(releaser.releaseCount, 1)
        let attemptCount = await executor.attemptCount()
        XCTAssertEqual(attemptCount, 2)
        XCTAssertEqual(router.closeCount, 1)
    }

    func testConflictKeepsFlowOpenAndDoesNotReleasePlayback() async {
        let executor = RenameTrackFileExecutorSpy()
        await executor.setOutcomes([.appError(.fileAlreadyExists)])
        let releaser = RenameTrackFilePlaybackReleaserSpy()
        let router = RenameTrackFileRouterSpy()
        let handler = makeActionHandler(
            executor: executor,
            playbackFileReleaser: releaser,
            router: router
        )

        let presentation = await handler.rename(
            trackId: UUID(),
            currentFileName: "Original.aiff",
            manualFileName: "Conflict"
        )

        XCTAssertEqual(presentation, .keepOpen(alert: .fileNameConflict))
        XCTAssertEqual(releaser.releaseCount, 0)
        XCTAssertEqual(router.closeCount, 0)
    }

    func testAppErrorUsesExistingToastAndKeepsFlowOpen() async {
        let executor = RenameTrackFileExecutorSpy()
        await executor.setOutcomes([.appError(.fileRenameFailed)])
        let toast = RenameTrackFileToastSpy()
        let router = RenameTrackFileRouterSpy()
        let handler = makeActionHandler(
            executor: executor,
            toast: toast,
            router: router
        )

        let presentation = await handler.rename(
            trackId: UUID(),
            currentFileName: "Original.mp3",
            manualFileName: "Renamed"
        )

        XCTAssertEqual(presentation, .keepOpen(alert: nil))
        XCTAssertEqual(toast.errors.count, 1)
        guard case .fileRenameFailed? = toast.errors.first else {
            return XCTFail("Должна быть показана исходная AppError переименования")
        }
        XCTAssertEqual(router.closeCount, 0)
    }

    func testUnknownErrorUsesExistingFailureMessageAndKeepsFlowOpen() async {
        let executor = RenameTrackFileExecutorSpy()
        await executor.setOutcomes([.unknown])
        let toast = RenameTrackFileToastSpy()
        let router = RenameTrackFileRouterSpy()
        let handler = makeActionHandler(
            executor: executor,
            toast: toast,
            router: router
        )

        let presentation = await handler.rename(
            trackId: UUID(),
            currentFileName: "Original.mp3",
            manualFileName: "Renamed"
        )

        XCTAssertEqual(presentation, .keepOpen(alert: nil))
        XCTAssertEqual(
            toast.events,
            [
                .operationFailed(
                    message: FileRenamePresentationText.fileRenameFailedMessage
                )
            ]
        )
        XCTAssertEqual(router.closeCount, 0)
    }

    func testCloseUsesOnlyTypedRouteWithoutSaving() async {
        let executor = RenameTrackFileExecutorSpy()
        let router = RenameTrackFileRouterSpy()
        let handler = makeActionHandler(
            executor: executor,
            router: router
        )

        handler.close()

        XCTAssertEqual(router.closeCount, 1)
        let requests = await executor.requests()
        XCTAssertTrue(requests.isEmpty)
    }

    func testViewModelAppliesStopPlaybackPresentationThroughActionChain() async {
        let (viewModel, executor, _, _, releaser) = makeViewModel()
        await executor.setOutcomes([.appError(.fileAccessDenied), .success])

        viewModel.send(.fileNameChanged("Renamed"))
        viewModel.send(.rename)
        await completeScheduledTask()

        XCTAssertEqual(viewModel.state.alert, .stopPlayback)
        XCTAssertFalse(viewModel.state.isProcessing)

        viewModel.send(.confirmStopPlayback)
        await completeScheduledTask()

        XCTAssertEqual(releaser.releaseCount, 1)
    }

    private func makeViewModel(
        currentFileName: String = "Original.mp3"
    ) -> (
        RenameTrackFileViewModel,
        RenameTrackFileExecutorSpy,
        RenameTrackFileToastSpy,
        RenameTrackFileRouterSpy,
        RenameTrackFilePlaybackReleaserSpy
    ) {
        let executor = RenameTrackFileExecutorSpy()
        let toast = RenameTrackFileToastSpy()
        let router = RenameTrackFileRouterSpy()
        let releaser = RenameTrackFilePlaybackReleaserSpy()
        let handler = makeActionHandler(
            executor: executor,
            toast: toast,
            playbackFileReleaser: releaser,
            router: router
        )
        let presenter = RenameTrackFilePresenter(toastPresenter: toast)
        let initialFileName = (currentFileName as NSString).deletingPathExtension
        let viewModel = RenameTrackFileViewModel(
            trackId: UUID(),
            currentFileName: currentFileName,
            initialFileName: initialFileName,
            presenter: presenter,
            actionHandler: handler
        )

        return (viewModel, executor, toast, router, releaser)
    }

    private func makeActionHandler(
        executor: RenameTrackFileExecutorSpy,
        toast: RenameTrackFileToastSpy? = nil,
        playbackFileReleaser: RenameTrackFilePlaybackReleaserSpy? = nil,
        router: RenameTrackFileRouterSpy
    ) -> RenameTrackFileActionHandler {
        let resolvedToast = toast ?? RenameTrackFileToastSpy()
        let resolvedPlaybackFileReleaser = playbackFileReleaser
            ?? RenameTrackFilePlaybackReleaserSpy()

        return RenameTrackFileActionHandler(
            fileBusyChecker: RenameTrackFileBusyCheckerSpy(),
            playbackFileReleaser: resolvedPlaybackFileReleaser,
            commandExecutor: executor,
            proposalBuilder: FileRenameProposalBuilder(),
            presenter: RenameTrackFilePresenter(toastPresenter: resolvedToast),
            router: router
        )
    }

    private func completeScheduledTask() async {
        // Даём MainActor и actor fake завершить созданную ViewModel асинхронную задачу на устройстве.
        try? await Task.sleep(nanoseconds: 100_000_000)

        for _ in 0..<8 {
            await Task.yield()
        }
    }
}

/// Запоминает параметры сохранения вместо выполнения файловой операции.
private actor RenameTrackFileExecutorSpy: RenameTrackFileCommandExecuting {
    private var outcomes: [RenameTrackFileExecutorOutcome] = [.success]
    private var saveRequests: [RenameTrackFileSaveRequest] = []
    private var attempts = 0

    func setOutcomes(_ outcomes: [RenameTrackFileExecutorOutcome]) {
        self.outcomes = outcomes
    }

    func requests() -> [RenameTrackFileSaveRequest] {
        saveRequests
    }

    func attemptCount() -> Int {
        attempts
    }

    func saveTrackEdits(
        trackId: UUID,
        newFileName: String,
        fileChanged: Bool,
        patch: TagWritePatch,
        tagsChanged: Bool,
        artworkAction: ArtworkWriteAction,
        artworkChanged: Bool,
        using fileBusyChecker: any TrackFileBusyChecking
    ) async throws -> TrackEditsSavedSuccess {
        attempts += 1
        saveRequests.append(
            RenameTrackFileSaveRequest(
                trackId: trackId,
                newFileName: newFileName,
                fileChanged: fileChanged,
                tagsChanged: tagsChanged,
                artworkChanged: artworkChanged
            )
        )

        let outcome = outcomes.isEmpty ? .success : outcomes.removeFirst()

        switch outcome {
        case .success:
            return TrackEditsSavedSuccess(
                trackId: trackId,
                finalFileName: newFileName,
                snapshot: nil,
                didUpdateTagsOrArtwork: false
            )

        case .appError(let error):
            throw error

        case .unknown:
            throw RenameTrackFileTestError.unknown
        }
    }
}

/// Результат, который fake command executor вернёт следующей попытке сохранения.
private enum RenameTrackFileExecutorOutcome {
    /// Возвращает успешный результат сохранения.
    case success
    /// Возвращает ожидаемую доменную ошибку приложения.
    case appError(AppError)
    /// Возвращает ошибку, не относящуюся к AppError.
    case unknown
}

/// Минимальный снимок параметров write-layer, важных для ручного rename-flow.
private struct RenameTrackFileSaveRequest {
    /// Идентификатор трека, переданный command executor.
    let trackId: UUID
    /// Подготовленное новое имя файла с исходным расширением.
    let newFileName: String
    /// Признак изменения имени файла.
    let fileChanged: Bool
    /// Признак отсутствия изменения тегов.
    let tagsChanged: Bool
    /// Признак отсутствия изменения обложки.
    let artworkChanged: Bool
}

/// Имитирует отсутствие занятости файла при тестировании передачи capability.
@MainActor
private final class RenameTrackFileBusyCheckerSpy: TrackFileBusyChecking {
    func isTrackFileBusy(trackId: UUID) -> Bool {
        false
    }
}

/// Запоминает подтверждённое освобождение текущего файла воспроизведения.
@MainActor
private final class RenameTrackFilePlaybackReleaserSpy: CurrentPlaybackFileReleasing {
    var releaseCount = 0

    func releaseCurrentPlaybackFile() {
        releaseCount += 1
    }
}

/// Запоминает сообщения, переданные flow в существующий presentation-слой.
@MainActor
private final class RenameTrackFileToastSpy: ToastPresenting {
    var events: [ToastEvent] = []
    var errors: [AppError] = []

    func handle(_ event: ToastEvent, duration: TimeInterval) {
        events.append(event)
    }

    func handle(_ error: AppError) {
        errors.append(error)
    }
}

/// Проверяет typed-маршрутизацию Rename Track File без зависимости от SheetManager.
@MainActor
private final class RenameTrackFileRouterSpy: RenameTrackFileRouting {
    var closeCount = 0

    func dismissRenameTrackFile(_ routeID: UUID) {
        closeCount += 1
    }
}

/// Представляет ошибку, которая не должна интерпретироваться как AppError.
private enum RenameTrackFileTestError: Error {
    case unknown
}
