//
//  LibraryCollectionTracksActionHandlerTests.swift
//  TrackList
//
//  Проверки экспорта треков выбранного значения музыкальной коллекции.
//
//  Created by Pavel Fomin on 20.07.2026.
//

import Foundation
import UIKit
import XCTest
@testable import TrackList

/// Проверяет действия списка выбранного значения без запуска picker-а и копирования файлов.
@MainActor
final class LibraryCollectionTracksActionHandlerTests: XCTestCase {

    /// Проверяет экспорт отображаемых секций в их порядке и с именем выбранного значения.
    func testExportUsesVisibleTracksInDisplayOrder() async {
        let exporter = CollectionTracksExportingSpy()
        let toastPresenter = CollectionTracksToastPresenterSpy()
        let source = LibraryTrackListSource.collectionValue(
            category: .genres,
            rawValue: "Techno",
            artistKey: nil
        )
        let handler = makeHandler(
            source: source,
            exportProgressViewModel: makeExportProgressViewModel(
                exporter: exporter,
                toastPresenter: toastPresenter
            ),
            toastPresenter: toastPresenter
        )
        let firstTrack = makeLibraryTrack(fileName: "First.flac")
        let secondTrack = makeLibraryTrack(fileName: "Second.FLAC")
        let visibleSections = [
            TrackSection(id: "later", title: "", tracks: [secondTrack], showsHeader: false),
            TrackSection(id: "earlier", title: "", tracks: [firstTrack], showsHeader: false)
        ]

        handler.handle(.exportTracks(visibleSections.flatMap(\.tracks)))
        await yieldToExportTask()

        XCTAssertEqual(exporter.exportCallCount, 1)
        XCTAssertEqual(exporter.exportFolderNames, ["Techno"])
        XCTAssertEqual(
            exporter.exportedTrackIDs,
            [[secondTrack.trackId, firstTrack.trackId]]
        )
        XCTAssertEqual(
            exporter.exportedFileNames,
            [[secondTrack.fileName, firstTrack.fileName]]
        )
        assertOriginalFileNamingMode(exporter.fileNamingModes)
        XCTAssertTrue(toastPresenter.events.isEmpty)
        XCTAssertTrue(toastPresenter.errors.isEmpty)
    }

    /// Проверяет, что пустой список выбранного значения не запускает экспорт.
    func testEmptyVisibleTracksDoesNotStartExport() async {
        let exporter = CollectionTracksExportingSpy()
        let toastPresenter = CollectionTracksToastPresenterSpy()
        let handler = makeHandler(
            source: .collectionValue(
                category: .labels,
                rawValue: "Лейбл",
                artistKey: nil
            ),
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

    /// Проверяет, что обработчик значения коллекции не заменяет обработчик общего списка «Треки».
    func testAllTracksSourceDoesNotStartCollectionValueExport() async {
        let exporter = CollectionTracksExportingSpy()
        let toastPresenter = CollectionTracksToastPresenterSpy()
        let handler = makeHandler(
            source: .allLibraryTracks,
            exportProgressViewModel: makeExportProgressViewModel(
                exporter: exporter,
                toastPresenter: toastPresenter
            ),
            toastPresenter: toastPresenter
        )

        handler.handle(.exportTracks([makeLibraryTrack(fileName: "Track.flac")]))
        await yieldToExportTask()

        XCTAssertEqual(exporter.exportCallCount, 0)
    }

    /// Проверяет явные признаки источников и отображаемые имена экспортных папок.
    func testSourcesExposeCollectionExportInformation() {
        let source = LibraryTrackListSource.collectionValue(
            category: .years,
            rawValue: "2024",
            artistKey: nil
        )

        XCTAssertTrue(LibraryTrackListSource.allLibraryTracks.isAllLibraryTracks)
        XCTAssertFalse(LibraryTrackListSource.allLibraryTracks.isCollectionValue)
        XCTAssertEqual(LibraryTrackListSource.allLibraryTracks.exportFolderName, "Треки")
        XCTAssertTrue(source.isCollectionValue)
        XCTAssertFalse(source.isAllLibraryTracks)
        XCTAssertEqual(source.collectionCategory, .years)
        XCTAssertEqual(source.exportFolderName, "2024")
        XCTAssertNil(LibraryTrackListSource.folder(folderId: UUID()).exportFolderName)
    }

    /// Проверяет, что доступные режимы сортировки корня категории остались прежними.
    func testCategoryValueSortModesStayUnchanged() {
        XCTAssertEqual(
            LibraryCollectionCategory.genres.availableValueSortModes,
            [.titleAscending, .titleDescending]
        )
        XCTAssertEqual(
            LibraryCollectionCategory.years.availableValueSortModes,
            [.yearNewestFirst, .yearOldestFirst]
        )
    }

    /// Собирает обработчик с управляемыми зависимостями.
    private func makeHandler(
        source: LibraryTrackListSource,
        exportProgressViewModel: ExportProgressViewModel,
        toastPresenter: CollectionTracksToastPresenterSpy
    ) -> LibraryCollectionTracksActionHandler {
        LibraryCollectionTracksActionHandler(
            source: source,
            exportProgressViewModel: exportProgressViewModel,
            viewControllerProvider: CollectionTracksViewControllerProviderSpy(
                presenter: UIViewController()
            ),
            toastPresenter: toastPresenter
        )
    }

    /// Собирает глобальное состояние экспорта с тестовым фасадом.
    private func makeExportProgressViewModel(
        exporter: CollectionTracksExportingSpy,
        toastPresenter: CollectionTracksToastPresenterSpy
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

    /// Проверяет использование режима сохранения исходного имени файла.
    private func assertOriginalFileNamingMode(_ modes: [ExportFileNamingMode]) {
        guard let fileNamingMode = modes.first else {
            return XCTFail("Режим именования не был передан в exporter")
        }
        guard case .original = fileNamingMode else {
            return XCTFail("Для значения коллекции ожидался режим original")
        }
    }

    /// Даёт задаче общего экспорта пройти несколько очередей MainActor.
    private func yieldToExportTask() async {
        for _ in 0..<6 {
            await Task.yield()
        }
    }
}

/// Тестовый фасад экспорта, сохраняющий параметры запроса без picker-а и копирования.
@MainActor
private final class CollectionTracksExportingSpy: TrackExporting {
    /// Количество попыток запуска экспорта.
    private(set) var exportCallCount = 0
    /// Имена дочерних папок экспорта.
    private(set) var exportFolderNames: [String] = []
    /// Режимы формирования имён файлов.
    private(set) var fileNamingModes: [ExportFileNamingMode] = []
    /// Идентификаторы экспортируемых треков в переданном порядке.
    private(set) var exportedTrackIDs: [[UUID]] = []
    /// Исходные имена экспортируемых файлов в переданном порядке.
    private(set) var exportedFileNames: [[String]] = []

    /// Сохраняет параметры и завершает экспорт успешным итогом.
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

/// Тестовый provider presenter-а системного picker-а.
@MainActor
private final class CollectionTracksViewControllerProviderSpy: ViewControllerProviding {
    /// UIViewController, который должен вернуть обработчику.
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
private final class CollectionTracksToastPresenterSpy: ToastPresenting {
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
