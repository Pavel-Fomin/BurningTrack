//
//  PlayerExportActionHandlerTests.swift
//  TrackList
//
//  Проверки передачи очереди плеера в общий экспорт.
//
//  Created by Pavel Fomin on 20.07.2026.
//

import Foundation
import XCTest
@testable import TrackList

/// Проверяет контракт экспорта текущей очереди плеера.
@MainActor
final class PlayerExportActionHandlerTests: XCTestCase {

    /// Проверяет передачу очереди в её текущем порядке с нумерованными именами.
    func testExportUsesCurrentQueueInOrderWithNumberedFileNames() {
        let playlistManager = PlaylistManager.shared
        let previousTracks = playlistManager.tracks
        defer { playlistManager.tracks = previousTracks }

        let firstTrack = makePlayerTrack(fileName: "First.flac")
        let secondTrack = makePlayerTrack(fileName: "Second.FLAC")
        playlistManager.tracks = [secondTrack, firstTrack]

        let exportRequestHandler = ExportRequestHandlerSpy()
        let handler = makeHandler(
            playlistManager: playlistManager,
            exportRequestHandler: exportRequestHandler
        )

        handler.exportTrackList()

        XCTAssertEqual(exportRequestHandler.requests.count, 1)
        XCTAssertEqual(
            exportRequestHandler.requests.first?.tracks.map(\.trackId),
            [secondTrack.trackId, firstTrack.trackId]
        )
        XCTAssertEqual(
            exportRequestHandler.requests.first?.tracks.map(\.fileName),
            [secondTrack.fileName, firstTrack.fileName]
        )
        XCTAssertEqual(exportRequestHandler.requests.first?.exportFolder, .playerQueue)
        assertNumberedFileNamingMode(
            exportRequestHandler.requests.first?.fileNamingMode
        )
    }

    /// Проверяет, что пустая очередь не запускает общий экспорт.
    func testEmptyQueuePassesEmptyRequestToGlobalValidation() {
        let playlistManager = PlaylistManager.shared
        let previousTracks = playlistManager.tracks
        defer { playlistManager.tracks = previousTracks }
        playlistManager.tracks = []

        let exportRequestHandler = ExportRequestHandlerSpy()
        let handler = makeHandler(
            playlistManager: playlistManager,
            exportRequestHandler: exportRequestHandler
        )

        handler.exportTrackList()

        XCTAssertEqual(exportRequestHandler.requests.count, 1)
        XCTAssertTrue(exportRequestHandler.requests.first?.tracks.isEmpty == true)
    }

    /// Собирает обработчик с тестовым глобальным состоянием экспорта.
    private func makeHandler(
        playlistManager: PlaylistManager,
        exportRequestHandler: any ExportRequestHandling
    ) -> PlayerExportActionHandler {
        PlayerExportActionHandler(
            playlistManager: playlistManager,
            exportRequestHandler: exportRequestHandler
        )
    }

    /// Создаёт минимальный элемент очереди плеера для проверки экспорта.
    private func makePlayerTrack(fileName: String) -> PlayerTrack {
        PlayerTrack(
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
            return XCTFail("Для плеера ожидался режим numbered")
        }
    }

}
