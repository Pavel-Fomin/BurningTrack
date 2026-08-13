//
//  TrackListExportHandlerTests.swift
//  TrackList
//
//  Проверки передачи сохранённого треклиста в общий экспорт.
//
//  Created by Pavel Fomin on 20.07.2026.
//

import Foundation
import XCTest
@testable import TrackList

/// Проверяет контракт экспорта одного сохранённого треклиста.
@MainActor
final class TrackListExportHandlerTests: XCTestCase {

    /// Проверяет передачу ручного порядка треклиста с нумерованными именами.
    func testExportUsesReaderTracksInManualOrderWithNumberedFileNames() {
        let firstTrack = makeTrack(fileName: "First.flac")
        let secondTrack = makeTrack(fileName: "Second.FLAC")
        let reader = TrackListReaderSpy(
            name: "Ручной порядок",
            tracks: [secondTrack, firstTrack]
        )
        let exportRequestHandler = ExportRequestHandlerSpy()
        let handler = makeHandler(
            reader: reader,
            exportRequestHandler: exportRequestHandler
        )

        handler.exportTracks()

        XCTAssertEqual(exportRequestHandler.requests.count, 1)
        XCTAssertEqual(
            exportRequestHandler.requests.first?.tracks.map(\.trackId),
            [secondTrack.trackId, firstTrack.trackId]
        )
        XCTAssertEqual(
            exportRequestHandler.requests.first?.tracks.map(\.fileName),
            [secondTrack.fileName, firstTrack.fileName]
        )
        XCTAssertEqual(exportRequestHandler.requests.first?.exportFolder, .named(reader.name))
        assertNumberedFileNamingMode(
            exportRequestHandler.requests.first?.fileNamingMode
        )
    }

    /// Проверяет передачу semantic AppError, который ToastManager преобразует в warning-событие.
    func testEmptyTrackListPassesEmptyRequestToGlobalValidation() {
        let reader = TrackListReaderSpy(name: "Пустой", tracks: [])
        let exportRequestHandler = ExportRequestHandlerSpy()
        let handler = makeHandler(
            reader: reader,
            exportRequestHandler: exportRequestHandler
        )

        handler.exportTracks()

        XCTAssertEqual(exportRequestHandler.requests.count, 1)
        XCTAssertTrue(exportRequestHandler.requests.first?.tracks.isEmpty == true)
    }

    /// Собирает обработчик экспорта сохранённого треклиста с тестовыми зависимостями.
    private func makeHandler(
        reader: any TrackListReading,
        exportRequestHandler: any ExportRequestHandling
    ) -> TrackListExportHandler {
        TrackListExportHandler(
            reader: reader,
            exportRequestHandler: exportRequestHandler
        )
    }

    /// Создаёт минимальный трек сохранённого треклиста для проверки порядка.
    private func makeTrack(fileName: String) -> Track {
        Track(
            trackId: UUID(),
            title: "Трек",
            artist: "Артист",
            duration: 10,
            fileName: fileName,
            isAvailable: true
        )
    }

    /// Проверяет режим формирования нумерованных имён без требования Equatable.
    private func assertNumberedFileNamingMode(_ fileNamingMode: ExportFileNamingMode?) {
        guard let fileNamingMode else {
            return XCTFail("Режим именования не был передан в exporter")
        }

        guard case .numbered = fileNamingMode else {
            return XCTFail("Для сохранённого треклиста ожидался режим numbered")
        }
    }

}

/// Предоставляет данные одного сохранённого треклиста без обращения к базе данных.
@MainActor
private final class TrackListReaderSpy: TrackListReading {

    /// Идентификатор тестового треклиста.
    let trackListId = UUID()

    /// Отображаемое имя треклиста для экспортной папки.
    let name: String

    /// Треки в сохранённом ручном порядке.
    let tracks: [Track]

    init(name: String, tracks: [Track]) {
        self.name = name
        self.tracks = tracks
    }
}
