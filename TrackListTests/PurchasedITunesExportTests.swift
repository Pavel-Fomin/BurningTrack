//
//  PurchasedITunesExportTests.swift
//  TrackListTests
//
//  Проверки обычного экспорта раздела «Куплено в iTunes».
//
//  Created by Pavel Fomin on 23.07.2026.
//

import Foundation
import UIKit
import XCTest
@testable import TrackList

/// Проверяет экранный маршрут и файловую ветку iTunes без системного picker-а.
final class PurchasedITunesExportTests: XCTestCase {

    /// Проверяет прямую запись assetURL и существующий формат имён без BookmarkResolver.
    func testServiceExportsPurchasedAssetsWithArtistTitleFileNames() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "PurchasedITunesExportTests-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let firstData = Data("first".utf8)
        let secondData = Data("second".utf8)
        let firstSourceURL = rootURL.appendingPathComponent("source-one.m4a")
        let secondSourceURL = rootURL.appendingPathComponent("source-two.m4a")
        try firstData.write(to: firstSourceURL)
        try secondData.write(to: secondSourceURL)

        let firstTrack = makeExportTrack(
            title: "One",
            artist: "Artist",
            assetURL: firstSourceURL
        )
        let secondTrack = makeExportTrack(
            title: "Two",
            artist: nil,
            assetURL: secondSourceURL
        )
        let job = ExportJob(
            tracks: [firstTrack, secondTrack],
            destination: ExportDestination(folderURL: rootURL),
            exportFolder: .purchasedITunes,
            fileNamingMode: .original
        )

        // Типизированный source фиксирует прямой runtime URL ещё до запуска сервиса.
        guard case .purchasedITunes(_, let firstAsset) = job.items[0].source else {
            return XCTFail("Первый iTunes-трек попал в bookmark-ветку")
        }
        XCTAssertEqual(firstAsset?.sourceURL, firstSourceURL)

        let summary = try await TrackExportService().export(job: job)
        let exportFolderURL = rootURL.appendingPathComponent(
            "Purchased iTunes",
            isDirectory: true
        )
        let firstDestinationURL = exportFolderURL
            .appendingPathComponent("Artist - One.m4a")
        let secondDestinationURL = exportFolderURL
            .appendingPathComponent("Two.m4a")

        XCTAssertEqual(summary.completedFiles, 2)
        XCTAssertTrue(summary.failedFiles.isEmpty)
        XCTAssertEqual(summary.state, .completed)
        XCTAssertEqual(try Data(contentsOf: firstDestinationURL), firstData)
        XCTAssertEqual(try Data(contentsOf: secondDestinationURL), secondData)
    }

    /// Создаёт transport-модель с отдельным iTunes source и готовым assetURL.
    private func makeExportTrack(
        title: String,
        artist: String?,
        assetURL: URL
    ) -> Track {
        Track(
            trackId: UUID(),
            title: title,
            artist: artist,
            duration: 1,
            fileName: title,
            isAvailable: true,
            source: .purchasedITunes,
            assetURL: assetURL
        )
    }
}

/// Проверяет экранный ActionHandler через существующее глобальное состояние экспорта.
@MainActor
final class PurchasedITunesMusicActionHandlerTests: XCTestCase {

    /// Проверяет папку, original-режим, порядок и сохранение прямых assetURL.
    func testExportUsesAllTracksInDisplayOrderWithoutNumbering() async {
        let exporter = ExportRequestSpy()
        let toastPresenter = ExportRequestToastPresenterSpy()
        let handler = PurchasedITunesMusicActionHandler(
            exportProgressViewModel: makeExportProgressViewModelForRequestTests(
                exporter: exporter,
                toastPresenter: toastPresenter
            ),
            viewControllerProvider: ExportRequestViewControllerProviderSpy(
                presenter: UIViewController()
            ),
            toastPresenter: toastPresenter
        )
        let firstTrack = makePlayableTrack(
            id: 1,
            title: "First",
            artist: "Artist",
            assetURL: URL(fileURLWithPath: "/tmp/first.m4a")
        )
        let secondTrack = makePlayableTrack(
            id: 2,
            title: "Second",
            artist: nil,
            assetURL: URL(fileURLWithPath: "/tmp/second.m4a")
        )

        handler.handle(.exportTracks([secondTrack, firstTrack]))
        await yieldToExportTask()

        XCTAssertEqual(exporter.exportCallCount, 1)
        XCTAssertEqual(exporter.exportFolderNames, ["Purchased iTunes"])
        XCTAssertEqual(
            exporter.exportedTrackIDs,
            [[secondTrack.trackId, firstTrack.trackId]]
        )
        XCTAssertEqual(
            exporter.exportedSources,
            [[.purchasedITunes, .purchasedITunes]]
        )
        XCTAssertEqual(
            exporter.exportedAssetURLs,
            [[secondTrack.assetURL, firstTrack.assetURL]]
        )
        guard let fileNamingMode = exporter.fileNamingModes.first else {
            return XCTFail("Режим именования не передан в общий экспорт")
        }
        guard case .original = fileNamingMode else {
            return XCTFail("Для iTunes ожидался обычный режим original")
        }
        XCTAssertTrue(toastPresenter.events.isEmpty)
        XCTAssertTrue(toastPresenter.errors.isEmpty)
    }

    /// Проверяет, что пустой раздел не открывает системный picker.
    func testEmptySectionDoesNotStartExport() async {
        let exporter = ExportRequestSpy()
        let toastPresenter = ExportRequestToastPresenterSpy()
        let handler = PurchasedITunesMusicActionHandler(
            exportProgressViewModel: makeExportProgressViewModelForRequestTests(
                exporter: exporter,
                toastPresenter: toastPresenter
            ),
            viewControllerProvider: ExportRequestViewControllerProviderSpy(
                presenter: UIViewController()
            ),
            toastPresenter: toastPresenter
        )

        handler.handle(.exportTracks([]))
        await yieldToExportTask()

        XCTAssertEqual(exporter.exportCallCount, 0)
        XCTAssertTrue(toastPresenter.events.isEmpty)
        XCTAssertTrue(toastPresenter.errors.isEmpty)
    }

    /// Создаёт runtime-адаптер без обращения к MediaPlayer.
    private func makePlayableTrack(
        id: UInt64,
        title: String,
        artist: String?,
        assetURL: URL
    ) -> PurchasedITunesPlayableTrack {
        PurchasedITunesPlayableTrack(
            track: PurchasedITunesTrack(
                id: id,
                title: title,
                artist: artist,
                album: nil,
                year: nil,
                genre: nil,
                dateAdded: Date(timeIntervalSince1970: 0),
                artworkData: nil,
                duration: 1,
                assetURL: assetURL
            )
        )
    }

    /// Даёт глобальному coordinator завершить тестовую задачу экспорта.
    private func yieldToExportTask() async {
        for _ in 0..<6 {
            await Task.yield()
        }
    }
}
