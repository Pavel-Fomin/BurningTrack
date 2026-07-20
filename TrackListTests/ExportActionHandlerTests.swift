//
//  ExportActionHandlerTests.swift
//  TrackList
//
//  Проверки сценариев запуска глобального экспорта.
//
//  Created by Pavel Fomin on 18.07.2026.
//

import Foundation
import UIKit
import XCTest
@testable import TrackList

/// Проверяет запуск экспорта и преобразование его ошибок в пользовательские сообщения.
@MainActor
final class ExportActionHandlerTests: XCTestCase {

    /// Проверяет отклонение пустого запроса без вызова exporter.
    func testStartExportWithEmptyTracksShowsWarning() async throws {
        let exporter = ExportingSpy()
        let toastPresenter = ToastPresenterSpy()
        let handler = makeHandler(
            exporter: exporter,
            toastPresenter: toastPresenter
        )
        var wasAccepted = false

        let result = try await handler.startExport(
            tracks: [],
            exportFolderName: "Плеер",
            fileNamingMode: .numbered,
            presenter: UIViewController(),
            onExportAccepted: {
                wasAccepted = true
            },
            onProgress: { _ in }
        )

        XCTAssertNil(result)
        XCTAssertFalse(wasAccepted)
        XCTAssertEqual(exporter.exportCallCount, 0)
        XCTAssertEqual(toastPresenter.events, [.noTracksToExport])
        XCTAssertTrue(toastPresenter.errors.isEmpty)
    }

    /// Проверяет передачу запроса exporter после принятия сценария.
    func testStartExportRunsExporterAndReturnsResult() async throws {
        let exporter = ExportingSpy()
        let toastPresenter = ToastPresenterSpy()
        let handler = makeHandler(
            exporter: exporter,
            toastPresenter: toastPresenter
        )
        let track = makeTrack()
        var wasAccepted = false

        let result = try await handler.startExport(
            tracks: [track],
            exportFolderName: "Экспорт",
            fileNamingMode: .numbered,
            presenter: UIViewController(),
            onExportAccepted: {
                wasAccepted = true
            },
            onProgress: { _ in }
        )

        XCTAssertEqual(result?.completedFiles, exporter.result.completedFiles)
        XCTAssertEqual(result?.failedFiles.count, exporter.result.failedFiles.count)
        XCTAssertEqual(result?.state, exporter.result.state)
        XCTAssertTrue(wasAccepted)
        XCTAssertEqual(exporter.exportCallCount, 1)
        XCTAssertEqual(exporter.exportFolderNames, ["Экспорт"])
        XCTAssertEqual(exporter.exportedTrackIDs, [[track.trackId]])
        guard let fileNamingMode = exporter.fileNamingModes.first else {
            XCTFail("Режим именования не был передан в exporter")
            return
        }
        if case .numbered = fileNamingMode {
            // Существующий экспорт должен сохранять нумерованные имена.
        } else {
            XCTFail("Для существующего экспорта ожидался режим numbered")
        }
        XCTAssertTrue(toastPresenter.events.isEmpty)
        XCTAssertTrue(toastPresenter.errors.isEmpty)
    }

    /// Проверяет пользовательское сообщение при активном экспорте сервиса.
    func testStartExportWithAlreadyRunningServiceShowsOperationMessage() async throws {
        let exporter = ExportingSpy()
        exporter.errorToThrow = TrackExportServiceError.exportAlreadyRunning
        let toastPresenter = ToastPresenterSpy()
        let handler = makeHandler(
            exporter: exporter,
            toastPresenter: toastPresenter
        )

        let result = try await startExport(handler: handler)

        XCTAssertNil(result)
        XCTAssertEqual(
            toastPresenter.events,
            [.operationFailed(message: "Экспорт уже выполняется")]
        )
        XCTAssertTrue(toastPresenter.errors.isEmpty)
    }

    /// Проверяет передачу ошибки приложения в централизованный канал Toast.
    func testStartExportWithAppErrorShowsAppError() async throws {
        let exporter = ExportingSpy()
        exporter.errorToThrow = AppError.exportFailed
        let toastPresenter = ToastPresenterSpy()
        let handler = makeHandler(
            exporter: exporter,
            toastPresenter: toastPresenter
        )

        let result = try await startExport(handler: handler)

        XCTAssertNil(result)
        XCTAssertEqual(toastPresenter.errors.count, 1)
        guard case .exportFailed = toastPresenter.errors.first else {
            return XCTFail("Ожидалась ошибка exportFailed")
        }
        XCTAssertTrue(toastPresenter.events.isEmpty)
    }

    /// Проверяет общее сообщение для инфраструктурной ошибки сервиса.
    func testStartExportWithServiceErrorShowsExportFailedMessage() async throws {
        let exporter = ExportingSpy()
        exporter.errorToThrow = TrackExportServiceError.destinationIsNotDirectory
        let toastPresenter = ToastPresenterSpy()
        let handler = makeHandler(
            exporter: exporter,
            toastPresenter: toastPresenter
        )

        let result = try await startExport(handler: handler)

        XCTAssertNil(result)
        XCTAssertEqual(toastPresenter.errors.count, 1)
        guard case .exportFailed = toastPresenter.errors.first else {
            return XCTFail("Ожидалась ошибка exportFailed")
        }
        XCTAssertTrue(toastPresenter.events.isEmpty)
    }

    /// Проверяет текст ошибки выбора папки из ExportDestinationResolver.
    func testStartExportWithResolverErrorShowsLocalizedMessage() async throws {
        let exporter = ExportingSpy()
        exporter.errorToThrow = ExportDestinationResolverError.pickerAlreadyPresented
        let toastPresenter = ToastPresenterSpy()
        let handler = makeHandler(
            exporter: exporter,
            toastPresenter: toastPresenter
        )

        let result = try await startExport(handler: handler)

        XCTAssertNil(result)
        XCTAssertEqual(
            toastPresenter.events,
            [
                .operationFailed(
                    message: ExportDestinationResolverError.pickerAlreadyPresented
                        .localizedDescription
                )
            ]
        )
        XCTAssertTrue(toastPresenter.errors.isEmpty)
    }

    /// Создаёт ActionHandler с управляемыми тестовыми зависимостями.
    private func makeHandler(
        exporter: ExportingSpy,
        toastPresenter: ToastPresenterSpy
    ) -> ExportActionHandler {
        ExportActionHandler(
            exporter: exporter,
            toastPresenter: toastPresenter
        )
    }

    /// Запускает непустой запрос, общий для сценариев обработки ошибок.
    private func startExport(
        handler: ExportActionHandler
    ) async throws -> ExportSummary? {
        try await handler.startExport(
            tracks: [makeTrack()],
            exportFolderName: "Плеер",
            fileNamingMode: .numbered,
            presenter: UIViewController(),
            onExportAccepted: {},
            onProgress: { _ in }
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
}

/// Тестовая реализация экспортного фасада без picker-а и файлового копирования.
@MainActor
private final class ExportingSpy: TrackExporting {

    /// Количество вызовов запуска экспорта.
    private(set) var exportCallCount = 0

    /// Имена папок, переданные при запусках экспорта.
    private(set) var exportFolderNames: [String] = []

    /// Режимы формирования имён, переданные при запусках экспорта.
    private(set) var fileNamingModes: [ExportFileNamingMode] = []

    /// Идентификаторы треков, переданные при запусках экспорта.
    private(set) var exportedTrackIDs: [[UUID]] = []

    /// Ошибка, которую exporter должен выбросить при запуске.
    var errorToThrow: Error?

    /// Результат успешного тестового экспорта.
    let result = ExportSummary(
        completedFiles: 1,
        failedFiles: [],
        state: .completed
    )

    /// Выполняет управляемый тестовый запуск.
    func exportTracks(
        _ tracks: [Track],
        exportFolderName: String,
        fileNamingMode: ExportFileNamingMode,
        presenter: UIViewController,
        onProgress: @escaping ExportProgressHandler
    ) async throws -> ExportSummary {
        exportCallCount += 1
        exportFolderNames.append(exportFolderName)
        fileNamingModes.append(fileNamingMode)
        exportedTrackIDs.append(tracks.map(\.trackId))

        if let errorToThrow {
            throw errorToThrow
        }

        return result
    }

    /// Не нужен сценариям обработки запуска, но сохраняет контракт TrackExporting.
    func cancelCurrentExport() {}
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

    /// Сохраняет ошибку приложения без показа реального Toast.
    func handle(_ error: AppError) {
        errors.append(error)
    }
}
