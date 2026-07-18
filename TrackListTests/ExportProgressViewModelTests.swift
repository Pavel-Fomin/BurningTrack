//
//  ExportProgressViewModelTests.swift
//  TrackList
//
//  Проверки глобального состояния и жизненного цикла экспорта.
//
//  Created by Pavel Fomin on 15.07.2026.
//

import Foundation
import UIKit
import XCTest
@testable import TrackList

/// Проверяет ViewModel без запуска picker-а, UI-тестов и файлового копирования.
@MainActor
final class ExportProgressViewModelTests: XCTestCase {

    /// Проверяет исходный единый снимок до появления операции экспорта.
    func testScreenStateIsHiddenBeforeExport() {
        let viewModel = makeViewModel(exporter: ExportingSpy())

        XCTAssertEqual(viewModel.screenState.phase, .hidden)
        XCTAssertNil(viewModel.screenState.progress)
        XCTAssertFalse(viewModel.screenState.isVisible)
        XCTAssertFalse(viewModel.screenState.isExportActive)
        XCTAssertFalse(viewModel.screenState.canCancel)
        XCTAssertFalse(viewModel.screenState.isShowingDetails)
    }

    /// Проверяет доставку промежуточного снимка прогресса.
    func testIntermediateProgressIsPublished() async {
        let exporter = ExportingSpy()
        exporter.snapshots = [
            makeProgress(state: .preparing),
            makeProgress(
                completedFiles: 1,
                copiedBytes: 40,
                totalBytes: 100,
                state: .copying
            )
        ]
        let viewModel = makeViewModel(exporter: exporter)

        viewModel.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Плеер",
            presenter: UIViewController()
        )
        await yieldToExportTask()

        XCTAssertEqual(viewModel.progress?.completedFiles, 1)
        XCTAssertEqual(viewModel.progress?.copiedBytes, 40)
        XCTAssertEqual(viewModel.progress?.state, .copying)
        XCTAssertEqual(viewModel.screenState.phase, .copying)
        XCTAssertEqual(viewModel.screenState.progress, viewModel.progress)
        XCTAssertTrue(viewModel.screenState.isVisible)
        XCTAssertTrue(viewModel.screenState.isExportActive)
        XCTAssertTrue(viewModel.screenState.canCancel)
    }

    /// Проверяет сохранение успешного результата после завершения операции.
    func testSuccessfulCompletionRemainsVisible() async {
        let exporter = ExportingSpy()
        exporter.snapshots = [
            makeProgress(
                completedFiles: 1,
                copiedBytes: 100,
                totalBytes: 100,
                state: .completed
            )
        ]
        let toastPresenter = ToastPresenterSpy()
        let viewModel = makeViewModel(
            exporter: exporter,
            toastPresenter: toastPresenter
        )

        viewModel.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Плеер",
            presenter: UIViewController()
        )
        await yieldToExportTask()

        XCTAssertEqual(viewModel.progress?.state, .completed)
        XCTAssertEqual(viewModel.progress?.completedFiles, 1)
        XCTAssertEqual(viewModel.progress?.copiedBytes, 100)
        XCTAssertEqual(viewModel.progress?.totalBytes, 100)
        XCTAssertTrue(viewModel.progress?.failedFiles.isEmpty == true)
        XCTAssertTrue(viewModel.isVisible)
        XCTAssertFalse(viewModel.isExportActive)
        XCTAssertFalse(viewModel.canCancel)
        XCTAssertEqual(viewModel.screenState.phase, .completed)
        XCTAssertTrue(viewModel.screenState.isVisible)
        XCTAssertFalse(viewModel.screenState.isExportActive)
        XCTAssertFalse(viewModel.screenState.canCancel)
        XCTAssertTrue(toastPresenter.errors.isEmpty)
        XCTAssertTrue(toastPresenter.events.isEmpty)
    }

    /// Проверяет, что частичный результат с ошибками доступен пользователю.
    func testCompletionWithErrorsRemainsVisible() async {
        let exporter = ExportingSpy()
        exporter.snapshots = [
            makeProgress(
                completedFiles: 1,
                copiedBytes: 100,
                totalBytes: 200,
                failedFiles: 1,
                state: .completedWithErrors
            )
        ]
        let viewModel = makeViewModel(exporter: exporter)

        viewModel.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Плеер",
            presenter: UIViewController()
        )
        await yieldToExportTask()

        XCTAssertEqual(viewModel.progress?.state, .completedWithErrors)
        XCTAssertEqual(viewModel.progress?.completedFiles, 1)
        XCTAssertEqual(viewModel.progress?.copiedBytes, 100)
        XCTAssertEqual(viewModel.progress?.totalBytes, 200)
        XCTAssertEqual(viewModel.progress?.failedFiles.count, 1)
        XCTAssertEqual(viewModel.progress?.failedFiles.first?.fileName, "01 track.flac")
        XCTAssertEqual(
            viewModel.progress?.failedFiles.first?.errorDescription,
            "Тестовая ошибка"
        )
        XCTAssertTrue(viewModel.isVisible)
        XCTAssertFalse(viewModel.isExportActive)
        XCTAssertEqual(viewModel.screenState.phase, .completedWithErrors)
    }

    /// Проверяет прохождение отмены до итогового снимка и освобождение блокировки.
    func testCancellationPublishesCancelledState() async {
        let exporter = ExportingSpy()
        exporter.holdsOperation = true
        exporter.snapshots = [makeProgress(state: .copying)]
        let viewModel = makeViewModel(exporter: exporter)

        viewModel.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Плеер",
            presenter: UIViewController()
        )
        await yieldToExportTask()

        viewModel.cancelExport()
        await yieldToExportTask()

        XCTAssertEqual(viewModel.progress?.state, .cancelled)
        XCTAssertFalse(viewModel.isExportActive)
        XCTAssertFalse(viewModel.canCancel)
        XCTAssertEqual(exporter.cancelCallCount, 1)

        XCTAssertFalse(viewModel.cancelExport())
        XCTAssertEqual(exporter.cancelCallCount, 1)

        exporter.sendProgress(
            makeProgress(state: .copying),
            forCall: 1
        )
        await yieldToExportTask()

        XCTAssertEqual(viewModel.progress?.state, .cancelled)
    }

    /// Проверяет, что action отмены использует существующий путь отмены.
    func testCancelActionUsesExistingCancellationPath() async {
        let exporter = ExportingSpy()
        exporter.holdsOperation = true
        exporter.snapshots = [makeProgress(state: .copying)]
        let viewModel = makeViewModel(exporter: exporter)

        viewModel.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Плеер",
            presenter: UIViewController()
        )
        await yieldToExportTask()

        viewModel.handle(.cancel)
        await yieldToExportTask()

        XCTAssertEqual(exporter.cancelCallCount, 1)
        XCTAssertEqual(viewModel.progress?.state, .cancelled)
        XCTAssertFalse(viewModel.isExportActive)
    }

    /// Проверяет закрытие подробного экрана сразу после принятия отмены.
    func testCancellationClosesDetailsAndDisablesCancel() async {
        let exporter = ExportingSpy()
        exporter.holdsOperation = true
        exporter.snapshots = [makeProgress(state: .copying)]
        let viewModel = makeViewModel(exporter: exporter)

        viewModel.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Плеер",
            presenter: UIViewController()
        )
        await yieldToExportTask()

        viewModel.presentDetails()
        XCTAssertEqual(SheetManager.shared.activeSheet, .exportProgress)

        XCTAssertTrue(viewModel.cancelExport())
        XCTAssertNil(SheetManager.shared.activeSheet)

        await yieldToExportTask()

        XCTAssertEqual(viewModel.progress?.state, .cancelled)
        XCTAssertFalse(viewModel.canCancel)
        XCTAssertFalse(viewModel.isShowingDetails)
    }

    /// Проверяет, что action очистки не скрывает активную операцию.
    func testDismissCompletedActionCannotClearActiveOperation() async {
        let exporter = ExportingSpy()
        exporter.holdsOperation = true
        exporter.snapshots = [makeProgress(state: .copying)]
        let viewModel = makeViewModel(exporter: exporter)

        viewModel.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Плеер",
            presenter: UIViewController()
        )
        await yieldToExportTask()

        viewModel.handle(.dismissCompleted)

        XCTAssertNotNil(viewModel.progress)
        XCTAssertTrue(viewModel.isExportActive)
        XCTAssertEqual(exporter.cancelCallCount, 0)

        viewModel.cancelExport()
        await yieldToExportTask()
    }

    /// Проверяет ручную очистку завершённой карточки.
    func testCompletedStateCanBeClearedManually() async {
        let exporter = ExportingSpy()
        exporter.snapshots = [makeProgress(state: .completed)]
        let viewModel = makeViewModel(exporter: exporter)

        viewModel.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Плеер",
            presenter: UIViewController()
        )
        await yieldToExportTask()

        viewModel.dismissCompletedExport()

        XCTAssertNil(viewModel.progress)
        XCTAssertFalse(viewModel.isVisible)
        XCTAssertEqual(exporter.exportCallCount, 1)
        XCTAssertEqual(exporter.cancelCallCount, 0)
    }

    /// Проверяет, что action очистки удаляет только завершённый результат.
    func testDismissCompletedActionClearsTerminalResult() async {
        let exporter = ExportingSpy()
        exporter.snapshots = [makeProgress(state: .completed)]
        let viewModel = makeViewModel(exporter: exporter)

        viewModel.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Плеер",
            presenter: UIViewController()
        )
        await yieldToExportTask()

        viewModel.handle(.dismissCompleted)

        XCTAssertNil(viewModel.progress)
        XCTAssertEqual(viewModel.screenState.phase, .hidden)
        XCTAssertFalse(viewModel.screenState.isVisible)
    }

    /// Проверяет запрет второго запуска на уровне ViewModel, а не только кнопки UI.
    func testSecondExportIsRejectedWhileFirstIsActive() async {
        let exporter = ExportingSpy()
        exporter.holdsOperation = true
        exporter.snapshots = [makeProgress(state: .copying)]
        let toastPresenter = ToastPresenterSpy()
        let viewModel = makeViewModel(
            exporter: exporter,
            toastPresenter: toastPresenter
        )

        viewModel.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Плеер",
            presenter: UIViewController()
        )
        await yieldToExportTask()

        viewModel.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Другой список",
            presenter: UIViewController()
        )

        XCTAssertEqual(exporter.exportCallCount, 1)
        XCTAssertEqual(toastPresenter.events.count, 1)
        XCTAssertEqual(viewModel.progress?.state, .copying)
        XCTAssertEqual(viewModel.progress?.completedFiles, 0)
        XCTAssertTrue(viewModel.isExportActive)

        viewModel.cancelExport()
        await yieldToExportTask()
    }

    /// Проверяет, что action запуска передаёт параметры в существующий экспорт.
    func testStartActionUsesExistingExportPath() async {
        let exporter = ExportingSpy()
        exporter.holdsOperation = true
        exporter.snapshots = [makeProgress(state: .copying)]
        let viewModel = makeViewModel(exporter: exporter)
        let track = makeTrack()

        viewModel.handle(
            .start(
                tracks: [track],
                exportFolderName: "Экспорт через action",
                presenter: UIViewController()
            )
        )
        await yieldToExportTask()

        XCTAssertEqual(exporter.exportCallCount, 1)
        XCTAssertEqual(exporter.exportFolderNames, ["Экспорт через action"])
        XCTAssertEqual(exporter.exportedTrackIDs, [[track.trackId]])
        XCTAssertTrue(viewModel.isExportActive)
        XCTAssertEqual(viewModel.progress?.state, .copying)

        viewModel.handle(.cancel)
        await yieldToExportTask()
    }

    /// Проверяет возможность нового запуска после полного успешного завершения.
    func testExportCanRestartAfterCompletion() async {
        let exporter = ExportingSpy()
        exporter.snapshotsByCall = [
            [
                makeProgress(
                    completedFiles: 1,
                    copiedBytes: 100,
                    totalBytes: 100,
                    state: .completed
                )
            ],
            [
                makeProgress(
                    completedFiles: 1,
                    copiedBytes: 200,
                    totalBytes: 200,
                    state: .completed
                )
            ]
        ]
        let viewModel = makeViewModel(exporter: exporter)

        viewModel.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Первый список",
            presenter: UIViewController()
        )
        await yieldToExportTask()

        XCTAssertEqual(viewModel.progress?.copiedBytes, 100)
        XCTAssertFalse(viewModel.isExportActive)

        viewModel.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Второй список",
            presenter: UIViewController()
        )

        XCTAssertNil(viewModel.progress)

        await yieldToExportTask()

        XCTAssertEqual(exporter.exportCallCount, 2)
        XCTAssertEqual(exporter.progressHandlerCount, 2)
        XCTAssertEqual(viewModel.progress?.state, .completed)
        XCTAssertEqual(viewModel.progress?.copiedBytes, 200)
        XCTAssertFalse(viewModel.isExportActive)
    }

    /// Проверяет новый запуск после фактического завершения отменённой операции.
    func testExportCanRestartAfterCancellation() async {
        let exporter = ExportingSpy()
        exporter.holdsOperationForCalls = [1]
        exporter.snapshotsByCall = [
            [makeProgress(state: .copying)],
            [
                makeProgress(
                    completedFiles: 1,
                    copiedBytes: 100,
                    totalBytes: 100,
                    state: .completed
                )
            ]
        ]
        let viewModel = makeViewModel(exporter: exporter)

        viewModel.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Первый список",
            presenter: UIViewController()
        )
        await yieldToExportTask()

        XCTAssertTrue(viewModel.cancelExport())
        await yieldToExportTask()

        XCTAssertEqual(viewModel.progress?.state, .cancelled)
        XCTAssertFalse(viewModel.isExportActive)

        viewModel.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Второй список",
            presenter: UIViewController()
        )
        await yieldToExportTask()

        XCTAssertEqual(exporter.cancelCallCount, 1)
        XCTAssertEqual(exporter.exportCallCount, 2)
        XCTAssertEqual(viewModel.progress?.state, .completed)
        XCTAssertFalse(viewModel.isExportActive)

        let secondOperationProgress = viewModel.progress
        exporter.sendProgress(
            makeProgress(
                copiedBytes: 900,
                totalBytes: 900,
                state: .failed
            ),
            forCall: 1
        )
        await yieldToExportTask()

        XCTAssertEqual(viewModel.progress, secondOperationProgress)
    }

    /// Проверяет, что callback завершённой операции не меняет состояние новой.
    func testLateProgressFromPreviousOperationDoesNotChangeCurrentOperation() async {
        let exporter = ExportingSpy()
        exporter.holdsOperationForCalls = [2]
        exporter.snapshotsByCall = [
            [
                makeProgress(
                    completedFiles: 1,
                    copiedBytes: 100,
                    totalBytes: 100,
                    state: .completed
                )
            ],
            [
                makeProgress(
                    copiedBytes: 20,
                    totalBytes: 200,
                    state: .copying
                )
            ]
        ]
        let viewModel = makeViewModel(exporter: exporter)

        viewModel.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Первый список",
            presenter: UIViewController()
        )
        await yieldToExportTask()

        viewModel.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Второй список",
            presenter: UIViewController()
        )
        await yieldToExportTask()

        let secondOperationProgress = viewModel.progress
        exporter.sendProgress(
            makeProgress(
                completedFiles: 9,
                copiedBytes: 900,
                totalBytes: 900,
                state: .failed
            ),
            forCall: 1
        )
        await yieldToExportTask()

        XCTAssertEqual(viewModel.progress, secondOperationProgress)
        XCTAssertEqual(viewModel.progress?.state, .copying)

        viewModel.cancelExport()
        await yieldToExportTask()
    }

    /// Фиксирует текущее поведение для всех terminal-состояний: поздний progress
    /// той же активной операции может заменить уже опубликованный результат.
    func testLateProgressAfterTerminalStateKeepsCurrentBehavior() async {
        let terminalStates: [ExportState] = [
            .completed,
            .completedWithErrors,
            .failed,
            .cancelled
        ]

        for terminalState in terminalStates {
            let exporter = ExportingSpy()
            exporter.holdsOperation = true
            exporter.snapshots = [
                makeProgress(
                    completedFiles: terminalState == .completed ? 1 : 0,
                    copiedBytes: terminalState == .completed ? 100 : 0,
                    totalBytes: 100,
                    failedFiles: terminalState == .completedWithErrors ? 1 : 0,
                    state: terminalState
                )
            ]
            let viewModel = makeViewModel(exporter: exporter)

            viewModel.startExport(
                tracks: [makeTrack()],
                exportFolderName: "Плеер",
                presenter: UIViewController()
            )
            await yieldToExportTask()

            XCTAssertEqual(viewModel.progress?.state, terminalState)

            exporter.sendProgress(
                makeProgress(
                    copiedBytes: 25,
                    totalBytes: 100,
                    state: .copying
                ),
                forCall: 1
            )
            await yieldToExportTask()

            XCTAssertEqual(viewModel.progress?.state, .copying)
            XCTAssertEqual(viewModel.screenState.phase, .copying)

            viewModel.cancelExport()
            await yieldToExportTask()
        }
    }

    /// Проверяет сохранение последнего callback после возврата итогового результата.
    func testFinalProgressSurvivesRelayBeforeReturnedResult() async {
        let exporter = ExportingSpy()
        exporter.snapshots = [
            makeProgress(
                copiedBytes: 20,
                totalBytes: 100,
                state: .copying
            ),
            makeProgress(
                completedFiles: 1,
                copiedBytes: 100,
                totalBytes: 100,
                state: .completed
            )
        ]
        exporter.results = [
            ExportSummary(
                completedFiles: 1,
                failedFiles: [],
                state: .completed
            )
        ]
        let viewModel = makeViewModel(exporter: exporter)

        viewModel.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Плеер",
            presenter: UIViewController()
        )
        await yieldToExportTask()

        XCTAssertEqual(viewModel.progress?.state, .completed)
        XCTAssertEqual(viewModel.progress?.completedFiles, 1)
        XCTAssertEqual(viewModel.progress?.copiedBytes, 100)
        XCTAssertNil(viewModel.progress?.currentFileName)
        XCTAssertFalse(viewModel.isExportActive)
    }

    /// Проверяет сохранение terminal failed-progress без показа лишнего Toast.
    func testFailedTerminalProgressRemainsVisibleAndAllowsRestart() async {
        let exporter = ExportingSpy()
        exporter.snapshotsByCall = [
            [makeProgress(failedFiles: 1, state: .failed)],
            [makeProgress(completedFiles: 1, state: .completed)]
        ]
        let toastPresenter = ToastPresenterSpy()
        let viewModel = makeViewModel(
            exporter: exporter,
            toastPresenter: toastPresenter
        )

        viewModel.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Первый список",
            presenter: UIViewController()
        )
        await yieldToExportTask()

        XCTAssertEqual(viewModel.progress?.state, .failed)
        XCTAssertTrue(viewModel.isVisible)
        XCTAssertFalse(viewModel.isExportActive)
        XCTAssertTrue(toastPresenter.errors.isEmpty)
        XCTAssertTrue(toastPresenter.events.isEmpty)

        viewModel.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Второй список",
            presenter: UIViewController()
        )
        await yieldToExportTask()

        XCTAssertEqual(exporter.exportCallCount, 2)
        XCTAssertEqual(viewModel.progress?.state, .completed)
    }

    /// Проверяет Toast для выброшенной ошибки и очистку активной операции.
    func testThrownErrorShowsToastAndAllowsRestart() async {
        let exporter = ExportingSpy()
        exporter.snapshotsByCall = [
            [makeProgress(state: .copying)],
            [makeProgress(completedFiles: 1, state: .completed)]
        ]
        exporter.errorToThrow = AppError.exportFailed
        let toastPresenter = ToastPresenterSpy()
        let viewModel = makeViewModel(
            exporter: exporter,
            toastPresenter: toastPresenter
        )

        viewModel.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Первый список",
            presenter: UIViewController()
        )
        await yieldToExportTask()

        XCTAssertFalse(viewModel.isExportActive)
        XCTAssertEqual(viewModel.progress?.state, .copying)
        XCTAssertEqual(toastPresenter.errors.count, 1)

        exporter.errorToThrow = nil
        viewModel.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Второй список",
            presenter: UIViewController()
        )
        await yieldToExportTask()

        XCTAssertEqual(exporter.exportCallCount, 2)
        XCTAssertEqual(viewModel.progress?.state, .completed)
        XCTAssertFalse(viewModel.isExportActive)
    }

    // MARK: - Helpers

    /// Создаёт ViewModel с тестовыми зависимостями.
    private func makeViewModel(
        exporter: ExportingSpy,
        toastPresenter: ToastPresenterSpy? = nil
    ) -> ExportProgressViewModel {
        let toastPresenter = toastPresenter ?? ToastPresenterSpy()
        return ExportProgressViewModel(
            coordinator: ExportOperationCoordinator(
                actionHandler: ExportActionHandler(
                    exporter: exporter,
                    toastPresenter: toastPresenter
                )
            ),
            toastPresenter: toastPresenter
        )
    }

    /// Создаёт минимальную модель трека для контракта запуска экспорта.
    private func makeTrack() -> Track {
        Track(
            trackId: UUID(),
            title: "Трек",
            artist: "Артист",
            duration: 10,
            fileName: "track.flac",
            isAvailable: true
        )
    }

    /// Создаёт снимок прогресса с нужным состоянием и счётчиками.
    private func makeProgress(
        completedFiles: Int = 0,
        copiedBytes: Int64 = 0,
        totalBytes: Int64 = 100,
        failedFiles: Int = 0,
        totalFiles: Int = 1,
        state: ExportState
    ) -> ExportProgress {
        let destination = ExportDestination(
            folderURL: URL(fileURLWithPath: "/tmp/export/Плеер")
        )
        var progress = ExportProgress(
            totalFiles: totalFiles,
            destination: destination,
            state: state
        )
        progress.completedFiles = completedFiles
        progress.totalBytes = totalBytes
        progress.copiedBytes = copiedBytes
        progress.failedFiles = (0..<failedFiles).map { index in
            ExportFileResult(
                fileName: "0\(index + 1) track.flac",
                errorDescription: "Тестовая ошибка"
            )
        }
        return progress
    }

    /// Даёт задаче экспорта пройти несколько очередей MainActor.
    private func yieldToExportTask() async {
        for _ in 0..<6 {
            await Task.yield()
        }
    }
}

/// Тестовый фасад экспорта, который не открывает UIDocumentPicker и не копирует файлы.
@MainActor
private final class ExportingSpy: TrackExporting {

    /// Количество фактических попыток запуска.
    private(set) var exportCallCount = 0

    /// Количество запросов отмены.
    private(set) var cancelCallCount = 0

    /// Имена папок, переданные при запусках экспорта.
    private(set) var exportFolderNames: [String] = []

    /// Идентификаторы треков, переданные при запусках экспорта.
    private(set) var exportedTrackIDs: [[UUID]] = []

    /// Снимки, которые spy отдаёт ViewModel по очереди.
    var snapshots: [ExportProgress] = []

    /// Снимки для отдельных запусков, если сценарий использует несколько операций.
    var snapshotsByCall: [[ExportProgress]] = []

    /// Результаты для отдельных запусков, если их нужно сопоставить с callback-ами.
    var results: [ExportSummary] = []

    /// Ошибка, которую spy выбрасывает вместо результата.
    var errorToThrow: Error?

    /// Задерживает завершение, чтобы проверить активное состояние.
    var holdsOperation = false

    /// Запуски, которые должны завершаться только после отмены.
    var holdsOperationForCalls: Set<Int> = []

    /// Callback-и всех запусков нужны для проверки запоздалых событий.
    private var progressHandlers: [ExportProgressHandler] = []

    /// Continuation удерживаемой операции.
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    /// Выполняет тестовый сценарий экспорта.
    func exportTracks(
        _ tracks: [Track],
        exportFolderName: String,
        presenter: UIViewController,
        onProgress: @escaping ExportProgressHandler
    ) async throws -> ExportSummary {
        exportCallCount += 1
        exportFolderNames.append(exportFolderName)
        exportedTrackIDs.append(tracks.map(\.trackId))
        progressHandlers.append(onProgress)

        let snapshotsForCall = snapshotsByCall.indices.contains(exportCallCount - 1)
            ? snapshotsByCall[exportCallCount - 1]
            : snapshots
        for snapshot in snapshotsForCall {
            onProgress(snapshot)
        }

        if holdsOperation || holdsOperationForCalls.contains(exportCallCount) {
            await withCheckedContinuation { continuation in
                releaseContinuation = continuation
            }
        }

        if Task.isCancelled {
            throw CancellationError()
        }

        if let errorToThrow {
            throw errorToThrow
        }

        let defaultResult = ExportSummary(
            completedFiles: 1,
            failedFiles: [],
            state: .completed
        )
        return results.indices.contains(exportCallCount - 1)
            ? results[exportCallCount - 1]
            : defaultResult
    }

    /// Завершает удерживаемую тестовую операцию.
    func cancelCurrentExport() {
        cancelCallCount += 1
        progressHandlers.last?(
            ExportProgress(
                totalFiles: 1,
                destination: ExportDestination(
                    folderURL: URL(fileURLWithPath: "/tmp/export/Плеер")
                ),
                state: .cancelled
            )
        )
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    /// Передаёт снимок callback-у выбранного запуска после его завершения.
    func sendProgress(_ snapshot: ExportProgress, forCall call: Int) {
        guard progressHandlers.indices.contains(call - 1) else { return }
        progressHandlers[call - 1](snapshot)
    }

    /// Возвращает количество зарегистрированных callback-ов операций.
    var progressHandlerCount: Int {
        progressHandlers.count
    }
}

/// Тестовый получатель пользовательских сообщений.
@MainActor
private final class ToastPresenterSpy: ToastPresenting {

    /// Полученные декларативные события.
    private(set) var events: [ToastEvent] = []

    /// Полученные ошибки приложения.
    private(set) var errors: [AppError] = []

    /// Сохраняет событие без показа реального Toast.
    func handle(_ event: ToastEvent, duration: TimeInterval) {
        events.append(event)
    }

    /// Сохраняет ошибку без показа реального Toast.
    func handle(_ error: AppError) {
        errors.append(error)
    }
}
