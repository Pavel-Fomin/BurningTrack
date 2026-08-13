//
//  LibraryAllTracksActionHandlerTests.swift
//  TrackList
//
//  Проверки экспорта общего списка треков фонотеки.
//
//  Created by Pavel Fomin on 20.07.2026.
//

import Foundation
import XCTest
@testable import TrackList

/// Проверяет действия общего списка без запуска picker-а и копирования файлов.
@MainActor
final class LibraryAllTracksActionHandlerTests: XCTestCase {

    /// Проверяет экспорт треков из отображаемых секций без строк категорий.
    func testExportUsesVisibleTracksInDisplayOrderWithOriginalFileNames() {
        let exportRequestHandler = ExportRequestHandlerSpy()
        let handler = makeHandler(exportRequestHandler: exportRequestHandler)
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

        XCTAssertEqual(exportRequestHandler.requests.count, 1)
        XCTAssertEqual(
            exportRequestHandler.requests.first?.tracks.map(\.trackId),
            [secondTrack.trackId, firstTrack.trackId]
        )
        XCTAssertEqual(
            exportRequestHandler.requests.first?.tracks.map(\.fileName),
            [secondTrack.fileName, firstTrack.fileName]
        )
        XCTAssertEqual(exportRequestHandler.requests.first?.exportFolder, .libraryTracks)
        guard let fileNamingMode = exportRequestHandler.requests.first?.fileNamingMode else {
            return XCTFail("Режим именования не был передан в ExportRequest")
        }
        guard case .original = fileNamingMode else {
            return XCTFail("Для общего списка ожидался режим original")
        }
    }

    /// Проверяет, что экспорт общего списка не запускается без видимых треков.
    func testEmptyVisibleTracksPassEmptyRequestToGlobalValidation() {
        let exportRequestHandler = ExportRequestHandlerSpy()
        let handler = makeHandler(exportRequestHandler: exportRequestHandler)

        handler.handle(.exportTracks([]))

        XCTAssertEqual(exportRequestHandler.requests.count, 1)
        XCTAssertTrue(exportRequestHandler.requests.first?.tracks.isEmpty == true)
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
        exportRequestHandler: any ExportRequestHandling
    ) -> LibraryAllTracksActionHandler {
        LibraryAllTracksActionHandler(
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

}
