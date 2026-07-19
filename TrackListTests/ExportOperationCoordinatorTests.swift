//
//  ExportOperationCoordinatorTests.swift
//  TrackList
//
//  Проверки жизненного цикла одной операции экспорта.
//
//  Created by Pavel Fomin on 18.07.2026.
//

import Foundation
import UIKit
import XCTest
@testable import TrackList

/// Проверяет управление операцией без ViewModel, SwiftUI и файлового копирования.
@MainActor
final class ExportOperationCoordinatorTests: XCTestCase {

    /// Проверяет принятие запроса, доставку progress и завершение операции.
    func testSuccessfulOperationLifecycle() async {
        let exporter = CoordinatorExportingSpy()
        exporter.snapshots = [
            makeProgress(state: .preparing),
            makeProgress(
                completedFiles: 1,
                copiedBytes: 100,
                totalBytes: 100,
                state: .completed
            )
        ]
        let coordinator = makeCoordinator(exporter: exporter)
        var acceptedCount = 0
        var receivedProgress: [ExportProgress] = []
        var finishedCount = 0
        coordinator.onExportAccepted = {
            acceptedCount += 1
        }
        coordinator.onProgress = { snapshot in
            receivedProgress.append(snapshot)
        }
        coordinator.onOperationFinished = {
            finishedCount += 1
        }

        XCTAssertTrue(startExport(coordinator))
        await yieldToCoordinator()

        XCTAssertEqual(acceptedCount, 1)
        XCTAssertEqual(receivedProgress.last?.state, .completed)
        XCTAssertEqual(receivedProgress.last?.copiedBytes, 100)
        XCTAssertEqual(finishedCount, 1)
        XCTAssertFalse(coordinator.isExportActive)
    }

    /// Проверяет штатную отмену через ActionHandler и освобождение операции.
    func testCancellationFinishesOperation() async {
        let exporter = CoordinatorExportingSpy()
        exporter.holdsOperationForCalls = [1]
        exporter.snapshots = [makeProgress(state: .copying)]
        let coordinator = makeCoordinator(exporter: exporter)
        var receivedProgress: [ExportProgress] = []
        var finishedCount = 0
        coordinator.onProgress = { snapshot in
            receivedProgress.append(snapshot)
        }
        coordinator.onOperationFinished = {
            finishedCount += 1
        }

        XCTAssertTrue(startExport(coordinator))
        await yieldToCoordinator()

        XCTAssertTrue(coordinator.isExportActive)
        XCTAssertTrue(coordinator.cancelExport())
        await yieldToCoordinator()

        XCTAssertEqual(exporter.cancelCallCount, 1)
        XCTAssertEqual(receivedProgress.last?.state, .cancelled)
        XCTAssertEqual(finishedCount, 1)
        XCTAssertFalse(coordinator.isExportActive)
        XCTAssertFalse(coordinator.cancelExport())
    }

    /// Проверяет доставку последнего снимка до освобождения завершённой операции.
    func testLastProgressIsDeliveredBeforeOperationFinishes() async {
        let exporter = CoordinatorExportingSpy()
        exporter.snapshots = [
            makeProgress(
                copiedBytes: 25,
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
        let coordinator = makeCoordinator(exporter: exporter)
        var receivedProgress: [ExportProgress] = []
        var wasActiveWhenFinished: Bool?
        coordinator.onProgress = { snapshot in
            receivedProgress.append(snapshot)
        }
        coordinator.onOperationFinished = { [weak coordinator] in
            wasActiveWhenFinished = coordinator?.isExportActive
        }

        XCTAssertTrue(startExport(coordinator))
        await yieldToCoordinator()

        XCTAssertEqual(receivedProgress.last?.state, .completed)
        XCTAssertEqual(receivedProgress.last?.copiedBytes, 100)
        XCTAssertEqual(wasActiveWhenFinished, false)
    }

    /// Проверяет, что callback завершённой операции не попадает в новый запуск.
    func testLateProgressFromPreviousOperationIsIgnored() async {
        let exporter = CoordinatorExportingSpy()
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
        exporter.holdsOperationForCalls = [2]
        let coordinator = makeCoordinator(exporter: exporter)
        var receivedProgress: [ExportProgress] = []
        coordinator.onProgress = { snapshot in
            receivedProgress.append(snapshot)
        }

        XCTAssertTrue(startExport(coordinator))
        await yieldToCoordinator()
        XCTAssertTrue(startExport(coordinator))
        await yieldToCoordinator()

        let currentProgress = receivedProgress.last
        exporter.sendProgress(
            makeProgress(
                completedFiles: 9,
                copiedBytes: 900,
                totalBytes: 900,
                state: .failed
            ),
            forCall: 1
        )
        await yieldToCoordinator()

        XCTAssertEqual(receivedProgress.last, currentProgress)
        XCTAssertEqual(receivedProgress.last?.state, .copying)

        XCTAssertTrue(coordinator.cancelExport())
        await yieldToCoordinator()
    }

    /// Проверяет повторный запуск после освобождения Task, operationID и relay.
    func testFinishedOperationReleasesResourcesForNextStart() async {
        let exporter = CoordinatorExportingSpy()
        exporter.snapshotsByCall = [
            [makeProgress(completedFiles: 1, state: .completed)],
            [makeProgress(completedFiles: 1, state: .completed)]
        ]
        let coordinator = makeCoordinator(exporter: exporter)

        XCTAssertTrue(startExport(coordinator))
        await yieldToCoordinator()

        XCTAssertFalse(coordinator.isExportActive)
        XCTAssertTrue(startExport(coordinator))
        await yieldToCoordinator()

        XCTAssertEqual(exporter.exportCallCount, 2)
        XCTAssertFalse(coordinator.isExportActive)
    }

    /// Проверяет, что Activity получает тот же поток снимков и завершается один раз.
    func testLiveActivityFollowsCoordinatorProgressLifecycle() async {
        let exporter = CoordinatorExportingSpy()
        exporter.snapshots = [
            makeProgress(state: .preparing),
            makeProgress(
                completedFiles: 1,
                copiedBytes: 100,
                totalBytes: 100,
                state: .completed
            )
        ]
        let liveActivityManager = CoordinatorLiveActivityManagerSpy()
        let coordinator = ExportOperationCoordinator(
            actionHandler: ExportActionHandler(
                exporter: exporter,
                toastPresenter: CoordinatorToastPresenterSpy()
            ),
            liveActivityManager: liveActivityManager
        )

        XCTAssertTrue(startExport(coordinator))
        await yieldToCoordinator()

        XCTAssertEqual(liveActivityManager.startCalls.count, 1)
        XCTAssertEqual(liveActivityManager.startCalls.first?.operationTitle, "Экспорт")
        XCTAssertEqual(liveActivityManager.startCalls.first?.subjectTitle, "Плеер")
        XCTAssertEqual(liveActivityManager.finishCalls.count, 1)
        XCTAssertEqual(liveActivityManager.finishCalls.first?.progress.phase, .completed)
    }

    /// Собирает Coordinator с тестовыми доменными зависимостями.
    private func makeCoordinator(
        exporter: CoordinatorExportingSpy
    ) -> ExportOperationCoordinator {
        ExportOperationCoordinator(
            actionHandler: ExportActionHandler(
                exporter: exporter,
                toastPresenter: CoordinatorToastPresenterSpy()
            )
        )
    }

    /// Запускает минимальный непустой экспортный запрос.
    private func startExport(
        _ coordinator: ExportOperationCoordinator
    ) -> Bool {
        coordinator.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Плеер",
            presenter: UIViewController()
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

    /// Создаёт снимок progress для проверки порядка событий операции.
    private func makeProgress(
        completedFiles: Int = 0,
        copiedBytes: Int64 = 0,
        totalBytes: Int64 = 100,
        state: ExportState
    ) -> ExportProgress {
        var progress = ExportProgress(
            totalFiles: 1,
            destination: ExportDestination(
                folderURL: URL(fileURLWithPath: "/tmp/export/Плеер")
            ),
            state: state
        )
        progress.completedFiles = completedFiles
        progress.copiedBytes = copiedBytes
        progress.totalBytes = totalBytes
        return progress
    }

    /// Даёт Task операции и короткой задаче доставки пройти MainActor.
    private func yieldToCoordinator() async {
        for _ in 0..<6 {
            await Task.yield()
        }
    }
}

/// Запоминает вызовы универсального контракта без обращения к ActivityKit.
@MainActor
private final class CoordinatorLiveActivityManagerSpy: ProgressLiveActivityManaging {

    /// Начальные снимки принятых операций.
    private(set) var startCalls: [StartCall] = []

    /// Итоговые снимки завершённых операций.
    private(set) var finishCalls: [FinishCall] = []

    /// Запоминает запуск Activity после первого реального снимка.
    func start(
        operationID: UUID,
        operationTitle: String,
        subjectTitle: String,
        progress: OperationProgress
    ) {
        startCalls.append(
            StartCall(
                operationID: operationID,
                operationTitle: operationTitle,
                subjectTitle: subjectTitle,
                progress: progress
            )
        )
    }

    /// Обновления нужны Coordinator-у, но для этого теста отдельно не сохраняются.
    func update(
        operationID: UUID,
        progress: OperationProgress
    ) {}

    /// Запоминает единственное терминальное событие.
    func finish(
        operationID: UUID,
        progress: OperationProgress
    ) {
        finishCalls.append(
            FinishCall(
                operationID: operationID,
                progress: progress
            )
        )
    }

    /// Данные вызова запуска для проверок теста.
    struct StartCall {
        let operationID: UUID
        let operationTitle: String
        let subjectTitle: String
        let progress: OperationProgress
    }

    /// Данные вызова завершения для проверок теста.
    struct FinishCall {
        let operationID: UUID
        let progress: OperationProgress
    }
}

/// Тестовый фасад экспорта без picker-а и файловой системы.
@MainActor
private final class CoordinatorExportingSpy: TrackExporting {

    /// Количество фактических запусков экспорта.
    private(set) var exportCallCount = 0

    /// Количество переданных запросов отмены.
    private(set) var cancelCallCount = 0

    /// Снимки, возвращаемые при любом запуске без индивидуального сценария.
    var snapshots: [ExportProgress] = []

    /// Снимки, сопоставленные с порядковым номером запуска.
    var snapshotsByCall: [[ExportProgress]] = []

    /// Запуски, которые завершаются только после явной отмены.
    var holdsOperationForCalls: Set<Int> = []

    /// Callback-и нужны для имитации запоздалых progress-событий.
    private var progressHandlers: [ExportProgressHandler] = []

    /// Continuation удерживаемой операции.
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    /// Передаёт подготовленные progress-снимки и возвращает итог операции.
    func exportTracks(
        _ tracks: [Track],
        exportFolderName: String,
        presenter: UIViewController,
        onProgress: @escaping ExportProgressHandler
    ) async throws -> ExportSummary {
        exportCallCount += 1
        progressHandlers.append(onProgress)

        let snapshotsForCall = snapshotsByCall.indices.contains(exportCallCount - 1)
            ? snapshotsByCall[exportCallCount - 1]
            : snapshots
        for snapshot in snapshotsForCall {
            onProgress(snapshot)
        }

        if holdsOperationForCalls.contains(exportCallCount) {
            await withCheckedContinuation { continuation in
                releaseContinuation = continuation
            }
        }

        if Task.isCancelled {
            throw CancellationError()
        }

        return ExportSummary(
            completedFiles: 1,
            failedFiles: [],
            state: .completed
        )
    }

    /// Передаёт итоговый cancelled-progress и освобождает удерживаемый запуск.
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

    /// Имитирует callback, пришедший после завершения выбранного запуска.
    func sendProgress(_ snapshot: ExportProgress, forCall call: Int) {
        guard progressHandlers.indices.contains(call - 1) else { return }
        progressHandlers[call - 1](snapshot)
    }
}

/// Принимает Toast-сообщения без показа пользовательского интерфейса.
@MainActor
private final class CoordinatorToastPresenterSpy: ToastPresenting {

    /// Игнорирует декларативное событие, не относящееся к жизненному циклу Coordinator.
    func handle(_ event: ToastEvent, duration: TimeInterval) {}

    /// Игнорирует ошибку, преобразуемую ActionHandler до возврата в Coordinator.
    func handle(_ error: AppError) {}
}
