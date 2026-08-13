//
//  ExportRequestActionHandlerTests.swift
//  TrackList
//
//  Проверки внешнего контракта запуска глобального экспорта.
//
//  Created by Pavel Fomin on 13.08.2026.
//

import Foundation
import XCTest
@testable import TrackList

/// Проверяет validation и передачу типизированного внешнего запроса в Export-feature.
@MainActor
final class ExportRequestActionHandlerTests: XCTestCase {

    /// Проверяет запуск существующей операции по непустому внешнему запросу.
    func testNonEmptyRequestStartsExistingExportFlow() async {
        let exporter = ExportRequestSpy()
        let toastPresenter = ExportRequestToastPresenterSpy()
        let viewModel = makeExportProgressViewModelForRequestTests(
            exporter: exporter,
            toastPresenter: toastPresenter
        )
        let handler = ExportRequestActionHandler(
            progressViewModel: viewModel,
            toastPresenter: toastPresenter
        )
        let track = makeTrack()

        handler.startExport(
            ExportRequest(
                tracks: [track],
                exportFolder: .named("Внешний запрос"),
                fileNamingMode: .numbered
            )
        )
        await yieldToExportTask()

        XCTAssertEqual(exporter.exportCallCount, 1)
        XCTAssertEqual(exporter.exportedTrackIDs, [[track.trackId]])
        XCTAssertEqual(exporter.exportFolderNames, ["Внешний запрос"])
        XCTAssertTrue(toastPresenter.events.isEmpty)
        XCTAssertTrue(toastPresenter.errors.isEmpty)
    }

    /// Проверяет единый semantic AppError для пустого запроса без запуска операции.
    func testEmptyRequestShowsExportNoTracksAndDoesNotStartOperation() async {
        let exporter = ExportRequestSpy()
        let toastPresenter = ExportRequestToastPresenterSpy()
        let viewModel = makeExportProgressViewModelForRequestTests(
            exporter: exporter,
            toastPresenter: toastPresenter
        )
        let handler = ExportRequestActionHandler(
            progressViewModel: viewModel,
            toastPresenter: toastPresenter
        )

        handler.startExport(
            ExportRequest(
                tracks: [],
                exportFolder: .libraryTracks,
                fileNamingMode: .original
            )
        )
        await yieldToExportTask()

        XCTAssertEqual(exporter.exportCallCount, 0)
        XCTAssertEqual(toastPresenter.errors, [.exportNoTracks])
        XCTAssertTrue(toastPresenter.events.isEmpty)
    }

    /// Создаёт минимальный трек для контракта запуска.
    private func makeTrack() -> Track {
        Track(
            trackId: UUID(),
            title: "Трек",
            artist: "Артист",
            duration: 10,
            fileName: "track.flac",
            isAvailable: true
        )
    }

    /// Даёт coordinator завершить задачу экспортного сценария.
    private func yieldToExportTask() async {
        for _ in 0..<6 {
            await Task.yield()
        }
    }
}
