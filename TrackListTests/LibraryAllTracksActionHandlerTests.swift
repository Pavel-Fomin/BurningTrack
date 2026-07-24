//
//  LibraryAllTracksActionHandlerTests.swift
//  TrackList
//
//  Проверки экспорта общего списка треков фонотеки.
//
//  Created by Pavel Fomin on 20.07.2026.
//

import Foundation
import UIKit
import XCTest
@testable import TrackList

/// Проверяет действия общего списка без запуска picker-а и копирования файлов.
@MainActor
final class LibraryAllTracksActionHandlerTests: XCTestCase {

    /// Проверяет экспорт треков из отображаемых секций без строк категорий.
    func testExportUsesVisibleTracksInDisplayOrderWithOriginalFileNames() async {
        let exporter = AllTracksExportingSpy()
        let toastPresenter = AllTracksToastPresenterSpy()
        let handler = makeHandler(
            exportProgressViewModel: makeExportProgressViewModel(
                exporter: exporter,
                toastPresenter: toastPresenter
            ),
            toastPresenter: toastPresenter
        )
        let firstTrack = makeLibraryTrack(fileName: "01 First.flac")
        let secondTrack = makeLibraryTrack(fileName: "02 Second.FLAC")
        let visibleSections = [
            TrackSection(
                id: "second",
                header: .hidden,
                tracks: [secondTrack]
            ),
            TrackSection(
                id: "first",
                header: .hidden,
                tracks: [firstTrack]
            )
        ]

        // Строки категорий имеют другой тип и не входят в секции музыкальных файлов.
        let visibleTracks = visibleSections.flatMap(\.tracks)
        handler.handle(.exportTracks(visibleTracks))
        await yieldToExportTask()

        XCTAssertEqual(exporter.exportCallCount, 1)
        XCTAssertEqual(exporter.exportFolderNames, ["Треки"])
        XCTAssertEqual(
            exporter.exportedTrackIDs,
            [[secondTrack.trackId, firstTrack.trackId]]
        )
        XCTAssertEqual(
            exporter.exportedFileNames,
            [[secondTrack.fileName, firstTrack.fileName]]
        )
        guard let fileNamingMode = exporter.fileNamingModes.first else {
            return XCTFail("Режим именования не был передан в exporter")
        }
        guard case .original = fileNamingMode else {
            return XCTFail("Для общего списка ожидался режим original")
        }
        XCTAssertTrue(toastPresenter.events.isEmpty)
        XCTAssertTrue(toastPresenter.errors.isEmpty)
    }

    /// Проверяет, что экспорт общего списка не запускается без видимых треков.
    func testExportWithEmptyVisibleTracksDoesNotStartExport() async {
        let exporter = AllTracksExportingSpy()
        let toastPresenter = AllTracksToastPresenterSpy()
        let handler = makeHandler(
            exportProgressViewModel: makeExportProgressViewModel(
                exporter: exporter,
                toastPresenter: toastPresenter
            ),
            toastPresenter: toastPresenter
        )

        handler.handle(.exportTracks([]))
        await yieldToExportTask()

        XCTAssertEqual(exporter.exportCallCount, 0)
        XCTAssertTrue(toastPresenter.events.isEmpty)
        XCTAssertTrue(toastPresenter.errors.isEmpty)
    }

    /// Проверяет, что типизированный источник явно отличает общий список от значения коллекции.
    func testAllTracksSourceDescribesItsExportCapabilities() {
        let collectionSource = LibraryTrackListSource.collectionValue(
            category: .artists,
            rawValue: "Артист",
            artistKey: nil
        )

        XCTAssertTrue(LibraryTrackListSource.allLibraryTracks.isAllLibraryTracks)
        XCTAssertFalse(LibraryTrackListSource.allLibraryTracks.isCollectionValue)
        XCTAssertEqual(LibraryTrackListSource.allLibraryTracks.exportFolder, .libraryTracks)
        XCTAssertFalse(collectionSource.isAllLibraryTracks)
        XCTAssertTrue(collectionSource.isCollectionValue)
        XCTAssertEqual(collectionSource.exportFolder, .named("Артист"))
    }

    /// Проверяет, что общий список сохраняет все существующие режимы сортировки.
    func testAllTracksSourceKeepsAllSortModesAvailable() {
        XCTAssertEqual(
            LibraryTrackListSource.allLibraryTracks.availableTrackSortModes,
            LibraryTrackSortMode.allCases
        )
    }

    /// Собирает обработчик общего списка с управляемыми зависимостями.
    private func makeHandler(
        exportProgressViewModel: ExportProgressViewModel,
        toastPresenter: AllTracksToastPresenterSpy
    ) -> LibraryAllTracksActionHandler {
        LibraryAllTracksActionHandler(
            exportProgressViewModel: exportProgressViewModel,
            viewControllerProvider: AllTracksViewControllerProviderSpy(
                presenter: UIViewController()
            ),
            toastPresenter: toastPresenter
        )
    }

    /// Собирает глобальное состояние экспорта с тестовым фасадом.
    private func makeExportProgressViewModel(
        exporter: AllTracksExportingSpy,
        toastPresenter: AllTracksToastPresenterSpy
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
private final class AllTracksExportingSpy: TrackExporting {

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
        exportFolder: ExportFolder,
        fileNamingMode: ExportFileNamingMode,
        presenter: UIViewController,
        onProgress: @escaping ExportProgressHandler
    ) async throws -> ExportSummary {
        exportCallCount += 1
        exportFolderNames.append(exportFolder.fileSystemName)
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
private final class AllTracksViewControllerProviderSpy: ViewControllerProviding {

    /// UIViewController, который должен вернуть обработчику общего списка.
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
private final class AllTracksToastPresenterSpy: ToastPresenting {

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
