//
//  TrackListExportHandlerTests.swift
//  TrackList
//
//  Проверки передачи сохранённого треклиста в общий экспорт.
//
//  Created by Pavel Fomin on 20.07.2026.
//

import Foundation
import UIKit
import XCTest
@testable import TrackList

/// Проверяет контракт экспорта одного сохранённого треклиста.
@MainActor
final class TrackListExportHandlerTests: XCTestCase {

    /// Проверяет передачу ручного порядка треклиста с нумерованными именами.
    func testExportUsesReaderTracksInManualOrderWithNumberedFileNames() async {
        let firstTrack = makeTrack(fileName: "First.flac")
        let secondTrack = makeTrack(fileName: "Second.FLAC")
        let reader = TrackListReaderSpy(
            name: "Ручной порядок",
            tracks: [secondTrack, firstTrack]
        )
        let exporter = ExportRequestSpy()
        let toastPresenter = ExportRequestToastPresenterSpy()
        let handler = makeHandler(
            reader: reader,
            exportProgressViewModel: makeExportProgressViewModelForRequestTests(
                exporter: exporter,
                toastPresenter: toastPresenter
            ),
            toastPresenter: toastPresenter
        )

        handler.exportTracks()
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
        XCTAssertEqual(exporter.exportFolderNames, [reader.name])
        assertNumberedFileNamingMode(exporter.fileNamingModes)
        XCTAssertTrue(toastPresenter.events.isEmpty)
        XCTAssertTrue(toastPresenter.errors.isEmpty)
    }

    /// Проверяет сохранение существующей обработки пустого треклиста.
    func testEmptyTrackListDoesNotStartExport() async {
        let reader = TrackListReaderSpy(name: "Пустой", tracks: [])
        let exporter = ExportRequestSpy()
        let toastPresenter = ExportRequestToastPresenterSpy()
        let handler = makeHandler(
            reader: reader,
            exportProgressViewModel: makeExportProgressViewModelForRequestTests(
                exporter: exporter,
                toastPresenter: toastPresenter
            ),
            toastPresenter: toastPresenter
        )

        handler.exportTracks()
        await yieldToExportTask()

        XCTAssertEqual(exporter.exportCallCount, 0)
        XCTAssertEqual(toastPresenter.events, [.noTracksToExport])
        XCTAssertTrue(toastPresenter.errors.isEmpty)
    }

    /// Собирает обработчик экспорта сохранённого треклиста с тестовыми зависимостями.
    private func makeHandler(
        reader: any TrackListReading,
        exportProgressViewModel: ExportProgressViewModel,
        toastPresenter: ExportRequestToastPresenterSpy
    ) -> TrackListExportHandler {
        TrackListExportHandler(
            reader: reader,
            exportProgressViewModel: exportProgressViewModel,
            viewControllerProvider: ExportRequestViewControllerProviderSpy(
                presenter: UIViewController()
            ),
            toastPresenter: toastPresenter
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
    private func assertNumberedFileNamingMode(_ modes: [ExportFileNamingMode]) {
        guard let fileNamingMode = modes.first else {
            return XCTFail("Режим именования не был передан в exporter")
        }

        guard case .numbered = fileNamingMode else {
            return XCTFail("Для сохранённого треклиста ожидался режим numbered")
        }
    }

    /// Даёт задаче общего экспорта пройти несколько очередей MainActor.
    private func yieldToExportTask() async {
        for _ in 0..<6 {
            await Task.yield()
        }
    }
}

/// Предоставляет данные одного сохранённого треклиста без обращения к базе данных.
@MainActor
private final class TrackListReaderSpy: TrackListReading {

    /// Идентификатор тестового треклиста.
    let currentListId: UUID? = UUID()

    /// Отображаемое имя треклиста для экспортной папки.
    let name: String

    /// Треки в сохранённом ручном порядке.
    let tracks: [Track]

    init(name: String, tracks: [Track]) {
        self.name = name
        self.tracks = tracks
    }
}
