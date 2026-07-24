//
//  ExportRequestTestSupport.swift
//  TrackList
//
//  Общие тестовые зависимости для проверки параметров запуска экспорта.
//
//  Created by Pavel Fomin on 20.07.2026.
//

import Foundation
import UIKit
import XCTest
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
        _ tracks: [Track],
        exportFolder: ExportFolder,
        fileNamingMode: ExportFileNamingMode,
        presenter: UIViewController,
        onProgress: @escaping ExportProgressHandler
    ) async throws -> ExportSummary {
        exportCallCount += 1
        exportedTrackIDs.append(tracks.map(\.trackId))
        exportedFileNames.append(tracks.map(\.fileName))
        exportedSources.append(tracks.map(\.source))
        exportedAssetURLs.append(tracks.map(\.assetURL))
        exportFolderNames.append(exportFolder.fileSystemName)
        fileNamingModes.append(fileNamingMode)

        return ExportSummary(
            completedFiles: tracks.count,
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

/// Возвращает заранее подготовленный presenter системного picker-а.
@MainActor
final class ExportRequestViewControllerProviderSpy: ViewControllerProviding {

    /// Presenter, который должен получить экспортный сценарий.
    private let presenter: UIViewController?

    init(presenter: UIViewController?) {
        self.presenter = presenter
    }

    /// Возвращает заданный presenter.
    func topViewController() -> UIViewController? {
        presenter
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
