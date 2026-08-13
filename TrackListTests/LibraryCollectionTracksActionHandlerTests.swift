//
//  LibraryCollectionTracksActionHandlerTests.swift
//  TrackList
//
//  Проверки экспорта треков выбранного значения музыкальной коллекции.
//
//  Created by Pavel Fomin on 20.07.2026.
//

import Foundation
import XCTest
@testable import TrackList

/// Проверяет действия списка выбранного значения без запуска picker-а и копирования файлов.
@MainActor
final class LibraryCollectionTracksActionHandlerTests: XCTestCase {

    /// Проверяет экспорт отображаемых секций в их порядке и с именем выбранного значения.
    func testExportUsesVisibleTracksInDisplayOrder() {
        let exportRequestHandler = ExportRequestHandlerSpy()
        let source = LibraryTrackListSource.collectionValue(
            category: .genres,
            rawValue: "Techno",
            artistKey: nil
        )
        let handler = makeHandler(
            source: source,
            exportRequestHandler: exportRequestHandler
        )
        let firstTrack = makeLibraryTrack(fileName: "First.flac")
        let secondTrack = makeLibraryTrack(fileName: "Second.FLAC")
        let visibleSections = [
            TrackSection(id: "later", header: .hidden, tracks: [secondTrack]),
            TrackSection(id: "earlier", header: .hidden, tracks: [firstTrack])
        ]

        handler.handle(.exportTracks(visibleSections.flatMap(\.tracks)))

        XCTAssertEqual(exportRequestHandler.requests.count, 1)
        XCTAssertEqual(
            exportRequestHandler.requests.first?.tracks.map(\.trackId),
            [secondTrack.trackId, firstTrack.trackId]
        )
        XCTAssertEqual(
            exportRequestHandler.requests.first?.tracks.map(\.fileName),
            [secondTrack.fileName, firstTrack.fileName]
        )
        XCTAssertEqual(exportRequestHandler.requests.first?.exportFolder, .named("Techno"))
        assertOriginalFileNamingMode(
            exportRequestHandler.requests.first?.fileNamingMode
        )
    }

    /// Проверяет, что пустой список выбранного значения не запускает экспорт.
    func testEmptyVisibleTracksPassEmptyRequestToGlobalValidation() {
        let exportRequestHandler = ExportRequestHandlerSpy()
        let handler = makeHandler(
            source: .collectionValue(
                category: .labels,
                rawValue: "Лейбл",
                artistKey: nil
            ),
            exportRequestHandler: exportRequestHandler
        )

        handler.handle(.exportTracks([]))

        XCTAssertEqual(exportRequestHandler.requests.count, 1)
        XCTAssertTrue(exportRequestHandler.requests.first?.tracks.isEmpty == true)
    }

    /// Проверяет, что обработчик значения коллекции не заменяет обработчик общего списка «Треки».
    func testAllTracksSourceDoesNotStartCollectionValueExport() {
        let exportRequestHandler = ExportRequestHandlerSpy()
        let handler = makeHandler(
            source: .allLibraryTracks,
            exportRequestHandler: exportRequestHandler
        )

        handler.handle(.exportTracks([makeLibraryTrack(fileName: "Track.flac")]))

        XCTAssertTrue(exportRequestHandler.requests.isEmpty)
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
        XCTAssertEqual(LibraryTrackListSource.allLibraryTracks.exportFolder, .libraryTracks)
        XCTAssertTrue(source.isCollectionValue)
        XCTAssertFalse(source.isAllLibraryTracks)
        XCTAssertEqual(source.collectionCategory, .years)
        XCTAssertEqual(source.exportFolder, .named("2024"))
        XCTAssertNil(LibraryTrackListSource.folder(folderId: UUID()).exportFolder)
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
        exportRequestHandler: any ExportRequestHandling
    ) -> LibraryCollectionTracksActionHandler {
        LibraryCollectionTracksActionHandler(
            source: source,
            exportRequestHandler: exportRequestHandler
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
    private func assertOriginalFileNamingMode(_ fileNamingMode: ExportFileNamingMode?) {
        guard let fileNamingMode else {
            return XCTFail("Режим именования не был передан в exporter")
        }
        guard case .original = fileNamingMode else {
            return XCTFail("Для значения коллекции ожидался режим original")
        }
    }

}
