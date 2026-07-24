//
//  TrackExportModelTests.swift
//  TrackList
//
//  Проверки чистых моделей задания и прогресса экспорта.
//
//  Created by Pavel Fomin on 15.07.2026.
//

import Foundation
import XCTest
@testable import TrackList

/// Проверяет контракт этапа 1 без запуска UI и файлового провайдера.
final class TrackExportModelTests: XCTestCase {

    /// Проверяет сохранение нумерации файлов в задании экспорта.
    func testExportJobPreservesNumbering() {
        let firstTrack = Track(
            trackId: UUID(),
            title: "Первый",
            artist: "Артист",
            duration: 10,
            fileName: "first.flac",
            isAvailable: true
        )
        let secondTrack = Track(
            trackId: UUID(),
            title: "Второй",
            artist: "Артист",
            duration: 20,
            fileName: "second.flac",
            isAvailable: true
        )
        let destination = ExportDestination(
            folderURL: URL(fileURLWithPath: "/tmp/export")
        )

        let job = ExportJob(
            tracks: [firstTrack, secondTrack],
            destination: destination,
            exportFolder: .named("Peak Time"),
            fileNamingMode: .numbered
        )

        XCTAssertEqual(job.exportFolderName, "Peak Time")
        XCTAssertEqual(job.items.map(\.exportFileName), [
            "01 first.flac",
            "02 second.flac"
        ])
    }

    /// Проверяет сохранение исходных имён, порядка и идентификаторов треков.
    func testExportJobPreservesOriginalFileNamesAndTrackOrder() {
        let firstTrackID = UUID()
        let secondTrackID = UUID()
        let firstFileName = "  Original 01.FLAC  "
        let secondFileName = "Live—Track.Mp3"
        let tracks = [
            Track(
                trackId: firstTrackID,
                title: "Первый",
                artist: "Артист",
                duration: 10,
                fileName: firstFileName,
                isAvailable: true
            ),
            Track(
                trackId: secondTrackID,
                title: "Второй",
                artist: "Артист",
                duration: 20,
                fileName: secondFileName,
                isAvailable: true
            )
        ]
        let destination = ExportDestination(
            folderURL: URL(fileURLWithPath: "/tmp/export")
        )

        let job = ExportJob(
            tracks: tracks,
            destination: destination,
            exportFolder: .named("Original"),
            fileNamingMode: .original
        )

        XCTAssertEqual(job.items.map(\.index), [0, 1])
        XCTAssertEqual(job.items.map(\.trackID), [firstTrackID, secondTrackID])
        XCTAssertEqual(job.items.map(\.exportFileName), [
            firstFileName,
            secondFileName
        ])
    }

    /// Проверяет наличие всех байтовых и файловых полей в снимке прогресса.
    func testExportProgressStartsWithZeroCounters() {
        let destination = ExportDestination(
            folderURL: URL(fileURLWithPath: "/tmp/export")
        )

        let progress = ExportProgress(
            totalFiles: 2,
            destination: destination,
            state: .preparing
        )

        XCTAssertEqual(progress.totalFiles, 2)
        XCTAssertEqual(progress.completedFiles, 0)
        XCTAssertEqual(progress.totalBytes, 0)
        XCTAssertEqual(progress.copiedBytes, 0)
        XCTAssertEqual(progress.currentFileBytes, 0)
        XCTAssertEqual(progress.currentFileCopiedBytes, 0)
        XCTAssertTrue(progress.failedFiles.isEmpty)
        XCTAssertEqual(progress.state, .preparing)
    }
}
