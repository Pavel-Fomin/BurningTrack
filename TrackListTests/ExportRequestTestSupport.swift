//
//  ExportRequestTestSupport.swift
//  TrackList
//
//  Общие тестовые зависимости для проверки параметров запуска экспорта.
//
//  Created by Pavel Fomin on 20.07.2026.
//

import Foundation
@testable import TrackList

/// Сохраняет параметры запроса экспорта без показа picker-а и копирования файлов.
@MainActor
final class ExportRequestSpy: TrackExporting {

    /// Количество принятых запросов экспорта.
    private(set) var exportCallCount = 0

    /// Идентификаторы треков каждого запроса в переданном порядке.
    private(set) var exportedTrackIDs: [[UUID]] = []

    /// Исходные имена файлов каждого запроса в переданном порядке.
    private(set) var exportedFileNames: [[String]] = []

    /// Источники треков каждого запроса сохраняют отличие iTunes от фонотеки.
    private(set) var exportedSources: [[TrackSource]] = []

    /// Runtime assetURL каждого запроса позволяют проверить обход BookmarkResolver.
    private(set) var exportedAssetURLs: [[URL?]] = []

    /// Имена дочерних экспортных папок.
    private(set) var exportFolderNames: [String] = []

    /// Режимы формирования имён файлов.
    private(set) var fileNamingModes: [ExportFileNamingMode] = []

    /// Количество запросов штатной отмены.
    private(set) var cancelCallCount = 0

    /// Сохраняет параметры и завершает тестовую операцию успешным итогом.
    func exportTracks(
        _ request: ExportRequest,
        onProgress: @escaping ExportProgressHandler
    ) async throws -> ExportSummary {
        exportCallCount += 1
        exportedTrackIDs.append(request.tracks.map(\.trackId))
        exportedFileNames.append(request.tracks.map(\.fileName))
        exportedSources.append(request.tracks.map(\.source))
        exportedAssetURLs.append(request.tracks.map(\.assetURL))
        exportFolderNames.append(request.exportFolder.fileSystemName)
        fileNamingModes.append(request.fileNamingMode)

        return ExportSummary(
            completedFiles: request.tracks.count,
            failedFiles: [],
            state: .completed
        )
    }

    /// Сохраняет запрос отмены без выполнения файловых операций.
    func cancelCurrentExport() {
        cancelCallCount += 1
    }
}

/// Сохраняет Toast-события, не создавая пользовательский интерфейс.
@MainActor
final class ExportRequestToastPresenterSpy: ToastPresenting {

    /// Декларативные события, полученные во время теста.
    private(set) var events: [ToastEvent] = []

    /// Ошибки приложения, полученные во время теста.
    private(set) var errors: [AppError] = []

    /// Сохраняет декларативное событие без показа Toast.
    func handle(_ event: ToastEvent, duration: TimeInterval) {
        events.append(event)
    }

    /// Сохраняет ошибку приложения без показа Toast.
    func handle(_ error: AppError) {
        errors.append(error)
    }
}

/// Сохраняет запросы маршрутизации подробностей без использования глобального SheetManager.
@MainActor
final class ExportDetailsRouterSpy: ExportDetailsRouting {

    /// Количество запросов открытия подробностей экспорта.
    private(set) var presentDetailsCallCount = 0

    /// Route каждого запроса открытия подробностей экспорта.
    private(set) var presentedRoutes: [ExportDetailsSheetRoute] = []

    /// Route каждого точечного explicit dismiss подробностей экспорта.
    private(set) var dismissedRoutes: [ExportDetailsSheetRoute] = []

    /// Сохраняет запрос открытия подробностей.
    func presentExportDetails() -> ExportDetailsSheetRoute {
        presentDetailsCallCount += 1
        let route = ExportDetailsSheetRoute()
        presentedRoutes.append(route)
        return route
    }

    /// Сохраняет запрос закрытия подробностей.
    func dismissExportDetails(_ route: ExportDetailsSheetRoute) {
        dismissedRoutes.append(route)
    }
}

/// Сохраняет запросы экранов без запуска глобальной операции.
@MainActor
final class ExportRequestHandlerSpy: ExportRequestHandling {

    /// Запросы, переданные экраном в глобальный Export-feature.
    private(set) var requests: [ExportRequest] = []

    /// Сохраняет типизированный запрос без запуска фоновой операции.
    func startExport(_ request: ExportRequest) {
        requests.append(request)
    }
}

/// Собирает глобальное состояние экспорта с тестовым фасадом.
@MainActor
func makeExportProgressViewModelForRequestTests(
    exporter: ExportRequestSpy,
    toastPresenter: ExportRequestToastPresenterSpy
) -> ExportProgressViewModel {
    ExportProgressViewModel(
        coordinator: ExportOperationCoordinator(
            actionHandler: ExportActionHandler(
                exporter: exporter,
                toastPresenter: toastPresenter
            )
        ),
        toastPresenter: toastPresenter
    )
}
