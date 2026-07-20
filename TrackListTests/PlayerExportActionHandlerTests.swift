//
//  PlayerExportActionHandlerTests.swift
//  TrackList
//
//  Проверки передачи очереди плеера в общий экспорт.
//
//  Created by Pavel Fomin on 20.07.2026.
//

import Foundation
import UIKit
import XCTest
@testable import TrackList

/// Проверяет контракт экспорта текущей очереди плеера.
@MainActor
final class PlayerExportActionHandlerTests: XCTestCase {

    /// Проверяет передачу очереди в её текущем порядке с нумерованными именами.
    func testExportUsesCurrentQueueInOrderWithNumberedFileNames() async {
        let playlistManager = PlaylistManager.shared
        let previousTracks = playlistManager.tracks
        defer { playlistManager.tracks = previousTracks }

        let firstTrack = makePlayerTrack(fileName: "First.flac")
        let secondTrack = makePlayerTrack(fileName: "Second.FLAC")
        playlistManager.tracks = [secondTrack, firstTrack]

        let exporter = ExportRequestSpy()
        let toastPresenter = ExportRequestToastPresenterSpy()
        let handler = makeHandler(
            playlistManager: playlistManager,
            exportProgressViewModel: makeExportProgressViewModelForRequestTests(
                exporter: exporter,
                toastPresenter: toastPresenter
            )
        )

        handler.exportTrackList()
        await yieldToExportTask()

        XCTAssertEqual(exporter.exportCallCount, 1)
        XCTAssertEqual(
            exporter.exportedTrackIDs,
            [[secondTrack.trackId, firstTrack.trackId]]
        )
        XCTAssertEqual(
            exporter.exportedFileNames,
            [[secondTrack.fileName, firstTrack.fileName]]
        )
        XCTAssertEqual(exporter.exportFolderNames, ["Плеер"])
        assertNumberedFileNamingMode(exporter.fileNamingModes)
    }

    /// Проверяет, что пустая очередь не запускает общий экспорт.
    func testEmptyQueueDoesNotStartExport() async {
        let playlistManager = PlaylistManager.shared
        let previousTracks = playlistManager.tracks
        defer { playlistManager.tracks = previousTracks }
        playlistManager.tracks = []

        let exporter = ExportRequestSpy()
        let toastPresenter = ExportRequestToastPresenterSpy()
        let handler = makeHandler(
            playlistManager: playlistManager,
            exportProgressViewModel: makeExportProgressViewModelForRequestTests(
                exporter: exporter,
                toastPresenter: toastPresenter
            )
        )

        handler.exportTrackList()
        await yieldToExportTask()

        XCTAssertEqual(exporter.exportCallCount, 0)
    }

    /// Собирает обработчик с тестовым глобальным состоянием экспорта.
    private func makeHandler(
        playlistManager: PlaylistManager,
        exportProgressViewModel: ExportProgressViewModel
    ) -> PlayerExportActionHandler {
        PlayerExportActionHandler(
            playlistManager: playlistManager,
            exportProgressViewModel: exportProgressViewModel,
            toastManager: .shared,
            presenterProvider: { UIViewController() }
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
    private func assertNumberedFileNamingMode(_ modes: [ExportFileNamingMode]) {
        guard let fileNamingMode = modes.first else {
            return XCTFail("Режим именования не был передан в exporter")
        }

        guard case .numbered = fileNamingMode else {
            return XCTFail("Для плеера ожидался режим numbered")
        }
    }

    /// Даёт задаче общего экспорта пройти несколько очередей MainActor.
    private func yieldToExportTask() async {
        for _ in 0..<6 {
            await Task.yield()
        }
    }
}
