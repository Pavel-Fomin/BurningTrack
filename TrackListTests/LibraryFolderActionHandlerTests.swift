//
//  LibraryFolderActionHandlerTests.swift
//  TrackList
//
//  Проверки экспорта треков из открытой папки фонотеки.
//
//  Created by Pavel Fomin on 20.07.2026.
//

import Foundation
import UIKit
import XCTest
@testable import TrackList

/// Проверяет действия открытой папки без запуска picker-а и копирования файлов.
@MainActor
final class LibraryFolderActionHandlerTests: XCTestCase {

    /// Проверяет экспорт только видимых треков в отображаемом порядке и без нумерации имён.
    func testExportUsesVisibleTracksInDisplayOrderWithOriginalFileNames() async {
        let exporter = FolderExportingSpy()
        let toastPresenter = FolderToastPresenterSpy()
        let folder = makeFolder(name: "Текущая папка")
        let viewModel = makeViewModel(
            folder: folder,
            exportProgressViewModel: makeExportProgressViewModel(
                exporter: exporter,
                toastPresenter: toastPresenter
            ),
            toastPresenter: toastPresenter
        )
        let firstTrack = makeLibraryTrack(fileName: "01 First.flac")
        let secondTrack = makeLibraryTrack(fileName: "02 Second.FLAC")
        let nestedTrack = makeLibraryTrack(fileName: "Nested.flac")

        viewModel.handle(.exportTracks([secondTrack, firstTrack]))
        await yieldToExportTask()

        XCTAssertEqual(exporter.exportCallCount, 1)
        XCTAssertEqual(exporter.exportFolderNames, [folder.name])
        XCTAssertEqual(
            exporter.exportedTrackIDs,
            [[secondTrack.trackId, firstTrack.trackId]]
        )
        XCTAssertEqual(
            exporter.exportedFileNames,
            [[secondTrack.fileName, firstTrack.fileName]]
        )
        XCTAssertFalse(
            exporter.exportedTrackIDs.flatMap { $0 }.contains(nestedTrack.trackId)
        )
        guard let fileNamingMode = exporter.fileNamingModes.first else {
            return XCTFail("Режим именования не был передан в exporter")
        }
        guard case .original = fileNamingMode else {
            return XCTFail("Для экспорта папки ожидался режим original")
        }
        XCTAssertTrue(toastPresenter.events.isEmpty)
        XCTAssertTrue(toastPresenter.errors.isEmpty)
    }

    /// Проверяет, что пустой список видимых треков не запускает экспорт.
    func testExportWithEmptyVisibleTracksDoesNotStartExport() async {
        let exporter = FolderExportingSpy()
        let toastPresenter = FolderToastPresenterSpy()
        let viewModel = makeViewModel(
            folder: makeFolder(name: "Пустая папка"),
            exportProgressViewModel: makeExportProgressViewModel(
                exporter: exporter,
                toastPresenter: toastPresenter
            ),
            toastPresenter: toastPresenter
        )

        viewModel.handle(.exportTracks([]))
        await yieldToExportTask()

        XCTAssertEqual(exporter.exportCallCount, 0)
        XCTAssertTrue(toastPresenter.events.isEmpty)
        XCTAssertTrue(toastPresenter.errors.isEmpty)
    }

    /// Проверяет сохранение существующего действия очистки панели выбора при появлении папки.
    func testAppearedClearsSelectionActionBar() {
        let exporter = FolderExportingSpy()
        let toastPresenter = FolderToastPresenterSpy()
        var clearSelectionCallCount = 0
        let viewModel = makeViewModel(
            folder: makeFolder(name: "Текущая папка"),
            exportProgressViewModel: makeExportProgressViewModel(
                exporter: exporter,
                toastPresenter: toastPresenter
            ),
            toastPresenter: toastPresenter,
            clearSelectionActionBar: {
                clearSelectionCallCount += 1
            }
        )

        viewModel.handle(.appeared)

        XCTAssertEqual(clearSelectionCallCount, 1)
    }

    /// Проверяет сохранение существующей навигации при выборе вложенной папки.
    func testSubfolderTapPushesFolderRoute() {
        let navigationCoordinator = NavigationCoordinator.shared
        navigationCoordinator.openLibraryRoot()
        defer { navigationCoordinator.openLibraryRoot() }

        let exporter = FolderExportingSpy()
        let toastPresenter = FolderToastPresenterSpy()
        let viewModel = makeViewModel(
            folder: makeFolder(name: "Текущая папка"),
            exportProgressViewModel: makeExportProgressViewModel(
                exporter: exporter,
                toastPresenter: toastPresenter
            ),
            toastPresenter: toastPresenter
        )
        let subfolder = makeFolder(name: "Вложенная папка")

        viewModel.handle(.subfolderTapped(subfolder))

        XCTAssertEqual(
            navigationCoordinator.libraryPath,
            [.folder(subfolder.url.libraryFolderId)]
        )
    }

    /// Собирает ViewModel папки с управляемыми зависимостями обработчика действий.
    private func makeViewModel(
        folder: LibraryFolder,
        exportProgressViewModel: ExportProgressViewModel,
        toastPresenter: FolderToastPresenterSpy,
        clearSelectionActionBar: @escaping @MainActor () -> Void = {}
    ) -> LibraryFolderViewModel {
        LibraryFolderViewModelFactory.make(
            folder: folder,
            navigationCoordinator: .shared,
            exportProgressViewModel: exportProgressViewModel,
            viewControllerProvider: FolderViewControllerProviderSpy(
                presenter: UIViewController()
            ),
            toastPresenter: toastPresenter,
            clearSelectionActionBar: clearSelectionActionBar
        )
    }

    /// Создаёт папку, название которой должно стать именем дочерней папки экспорта.
    private func makeFolder(name: String) -> LibraryFolder {
        LibraryFolder(
            name: name,
            url: URL(fileURLWithPath: "/tmp/\(name)")
        )
    }

    /// Собирает глобальное состояние экспорта с тестовым фасадом.
    private func makeExportProgressViewModel(
        exporter: FolderExportingSpy,
        toastPresenter: FolderToastPresenterSpy
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

    /// Создаёт минимальный трек фонотеки для проверки состава экспорта.
    private func makeLibraryTrack(fileName: String) -> LibraryTrack {
        LibraryTrack(
            id: UUID(),
            fileURL: URL(fileURLWithPath: "/tmp/\(fileName)"),
            title: "Трек",
            artist: "Артист",
            duration: 10,
            addedDate: Date()
        )
    }

    /// Даёт задаче общего экспорта пройти несколько очередей MainActor.
    private func yieldToExportTask() async {
        for _ in 0..<6 {
            await Task.yield()
        }
    }
}

/// Тестовый фасад экспорта, который сохраняет параметры запроса без picker-а и копирования.
@MainActor
private final class FolderExportingSpy: TrackExporting {

    /// Количество попыток запуска экспорта.
    private(set) var exportCallCount = 0

    /// Имена дочерних папок, переданные при экспорте.
    private(set) var exportFolderNames: [String] = []

    /// Режимы формирования имён файлов, переданные при экспорте.
    private(set) var fileNamingModes: [ExportFileNamingMode] = []

    /// Идентификаторы треков в порядке, переданном общему экспорту.
    private(set) var exportedTrackIDs: [[UUID]] = []

    /// Исходные имена файлов в порядке, переданном общему экспорту.
    private(set) var exportedFileNames: [[String]] = []

    /// Сохраняет параметры запроса и завершает экспорт успешным итогом.
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
        exportedFileNames.append(tracks.map(\.fileName))

        return ExportSummary(
            completedFiles: tracks.count,
            failedFiles: [],
            state: .completed
        )
    }

    /// Не нужен тестовым сценариям, но сохраняет контракт экспортного фасада.
    func cancelCurrentExport() {}
}

/// Тестовый провайдер presenter-а системного picker-а.
@MainActor
private final class FolderViewControllerProviderSpy: ViewControllerProviding {

    /// UIViewController, который должен вернуть обработчику папки.
    private let presenter: UIViewController?

    init(presenter: UIViewController?) {
        self.presenter = presenter
    }

    /// Возвращает заранее подготовленный presenter.
    func topViewController() -> UIViewController? {
        presenter
    }
}

/// Тестовый получатель пользовательских сообщений.
@MainActor
private final class FolderToastPresenterSpy: ToastPresenting {

    /// Декларативные события, которые получил обработчик.
    private(set) var events: [ToastEvent] = []

    /// Ошибки приложения, которые получил обработчик.
    private(set) var errors: [AppError] = []

    /// Сохраняет событие без показа пользовательского интерфейса.
    func handle(_ event: ToastEvent, duration: TimeInterval) {
        events.append(event)
    }

    /// Сохраняет ошибку приложения без показа пользовательского интерфейса.
    func handle(_ error: AppError) {
        errors.append(error)
    }
}
