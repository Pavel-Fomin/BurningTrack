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
        let viewModel = makeViewModel(exporter: exporter)

        viewModel.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Плеер",
            presenter: UIViewController()
        )
        await yieldToExportTask()

        XCTAssertEqual(viewModel.progress?.state, .completed)
        XCTAssertTrue(viewModel.isVisible)
        XCTAssertFalse(viewModel.isExportActive)
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
        XCTAssertEqual(viewModel.progress?.failedFiles.count, 1)
        XCTAssertTrue(viewModel.isVisible)
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
        XCTAssertEqual(exporter.cancelCallCount, 1)
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

    /// Проверяет, что активная операцию нельзя скрыть из глобального состояния.
    func testActiveOperationCannotBeDismissed() async {
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

        viewModel.dismissCompletedExport()

        XCTAssertNotNil(viewModel.progress)
        XCTAssertTrue(viewModel.isExportActive)

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
    }

    /// Проверяет запрет второго запуска на уровне ViewModel, а не только кнопки UI.
    func testSecondExportIsRejectedWhileFirstIsActive() async {
        let exporter = ExportingSpy()
        exporter.holdsOperation = true
        exporter.snapshots = [makeProgress(state: .copying)]
        let toastPresenter = ToastPresenterSpy()
        let viewModel = ExportProgressViewModel(
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

        viewModel.cancelExport()
        await yieldToExportTask()
    }

    // MARK: - Helpers

    /// Создаёт ViewModel с тестовыми зависимостями.
    private func makeViewModel(
        exporter: ExportingSpy
    ) -> ExportProgressViewModel {
        ExportProgressViewModel(
            exporter: exporter,
            toastPresenter: ToastPresenterSpy()
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
        state: ExportState
    ) -> ExportProgress {
        let destination = ExportDestination(
            folderURL: URL(fileURLWithPath: "/tmp/export/Плеер")
        )
        var progress = ExportProgress(
            totalFiles: 1,
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

    /// Снимки, которые spy отдаёт ViewModel по очереди.
    var snapshots: [ExportProgress] = []

    /// Задерживает завершение, чтобы проверить активное состояние.
    var holdsOperation = false

    /// Callback текущего запуска нужен для передачи состояния отмены.
    private var progressHandler: ExportProgressHandler?

    /// Continuation удерживаемой операции.
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    /// Выполняет тестовый сценарий экспорта.
    func exportTracks(
        _ tracks: [Track],
        exportFolderName: String,
        presenter: UIViewController,
        onProgress: @escaping ExportProgressHandler
    ) async throws -> ExportManager.ExportResult {
        exportCallCount += 1
        progressHandler = onProgress

        for snapshot in snapshots {
            onProgress(snapshot)
        }

        if holdsOperation {
            await withCheckedContinuation { continuation in
                releaseContinuation = continuation
            }
        }

        if Task.isCancelled {
            throw CancellationError()
        }

        let destination = ExportDestination(
            folderURL: URL(fileURLWithPath: "/tmp/export/Плеер")
        )
        return ExportManager.ExportResult(
            completedFiles: 1,
            failedFiles: [],
            state: .completed
        )
    }

    /// Завершает удерживаемую тестовую операцию.
    func cancelCurrentExport() {
        cancelCallCount += 1
        progressHandler?(
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
