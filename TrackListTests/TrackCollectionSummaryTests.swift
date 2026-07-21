//
//  TrackCollectionSummaryTests.swift
//  TrackListTests
//
//  Проверки общей статистики музыкальных коллекций и её SQLite-запросов.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import Foundation
import XCTest
@testable import TrackList

final class TrackCollectionSummaryTests: XCTestCase {
    private var database: AppDatabase?
    private var databaseDirectory: URL?

    override func tearDownWithError() throws {
        // Закрываем временную базу до удаления файлов WAL и SHM.
        try database?.close()
        database = nil

        if let databaseDirectory {
            try? FileManager.default.removeItem(at: databaseDirectory)
        }
        databaseDirectory = nil

        try super.tearDownWithError()
    }

    func testCompletenessFlagsReflectUnknownValues() {
        let complete = TrackCollectionSummary(
            trackCount: 1,
            totalDuration: 60,
            totalFileSize: 1,
            unknownDurationCount: 0,
            unknownFileSizeCount: 0
        )
        let incomplete = TrackCollectionSummary(
            trackCount: 1,
            totalDuration: nil,
            totalFileSize: nil,
            unknownDurationCount: 1,
            unknownFileSizeCount: 1
        )

        XCTAssertTrue(complete.hasCompleteDuration)
        XCTAssertTrue(complete.hasCompleteFileSize)
        XCTAssertFalse(incomplete.hasCompleteDuration)
        XCTAssertFalse(incomplete.hasCompleteFileSize)
    }

    func testFormatterUsesRussianTrackDeclensionAndCollectionDuration() {
        XCTAssertEqual(
            TrackCollectionSummaryFormatter.string(from: makeSummary(count: 0)),
            "0 треков"
        )
        XCTAssertEqual(
            TrackCollectionSummaryFormatter.string(from: makeSummary(count: 1, duration: 240)),
            "1 трек • 4 мин"
        )
        XCTAssertEqual(
            TrackCollectionSummaryFormatter.string(from: makeSummary(count: 2, duration: 480)),
            "2 трека • 8 мин"
        )
        XCTAssertEqual(
            TrackCollectionSummaryFormatter.string(from: makeSummary(count: 5, duration: 4_080)),
            "5 треков • 1 ч 08 мин"
        )
    }

    func testFormatterUsesSystemFileSizeFormattingForMegabytesAndGigabytes() {
        let megabytes = Int64(12 * 1_024 * 1_024)
        let gigabytes = Int64(5 * 1_024 * 1_024 * 1_024)

        XCTAssertEqual(
            TrackCollectionSummaryFormatter.string(from: makeSummary(count: 1, fileSize: megabytes)),
            "1 трек • \(ByteCountFormatter.string(fromByteCount: megabytes, countStyle: .file))"
        )
        XCTAssertEqual(
            TrackCollectionSummaryFormatter.string(from: makeSummary(count: 5, fileSize: gigabytes)),
            "5 треков • \(ByteCountFormatter.string(fromByteCount: gigabytes, countStyle: .file))"
        )
    }

    func testFormatterHidesOnlyIncompleteTotals() {
        let incompleteDuration = TrackCollectionSummary(
            trackCount: 5,
            totalDuration: 60,
            totalFileSize: 1_024,
            unknownDurationCount: 1,
            unknownFileSizeCount: 0
        )
        let incompleteSize = TrackCollectionSummary(
            trackCount: 5,
            totalDuration: 60,
            totalFileSize: 1_024,
            unknownDurationCount: 0,
            unknownFileSizeCount: 1
        )

        XCTAssertEqual(
            TrackCollectionSummaryFormatter.string(from: incompleteDuration),
            "5 треков • \(ByteCountFormatter.string(fromByteCount: 1_024, countStyle: .file))"
        )
        XCTAssertEqual(
            TrackCollectionSummaryFormatter.string(from: incompleteSize),
            "5 треков • 1 мин"
        )
    }

    func testFolderSummaryIsEmptyForFolderWithoutTracks() async throws {
        let database = try makeDatabase()
        let provider = try SQLiteTrackCollectionSummaryProvider(database: database)

        let summary = try await provider.summaryForFolder(folderId: UUID())

        XCTAssertEqual(
            summary,
            TrackCollectionSummary(
                trackCount: 0,
                totalDuration: nil,
                totalFileSize: nil,
                unknownDurationCount: 0,
                unknownFileSizeCount: 0
            )
        )
    }

    func testFolderSummaryCountsDirectActiveTracksAndSavedUnavailableData() async throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let folderStore = SQLiteFolderStore(executor: executor)
        let trackStore = SQLiteTrackStore(executor: executor)
        let metadataStore = SQLiteTrackMetadataStore(executor: executor)
        let provider = SQLiteTrackCollectionSummaryProvider(executor: executor)
        let rootFolderId = UUID()
        let folderId = UUID()
        let childFolderId = UUID()

        try insertFolder(id: rootFolderId, into: folderStore, isRoot: true)
        try insertFolder(
            id: folderId,
            parentFolderId: rootFolderId,
            rootFolderId: rootFolderId,
            into: folderStore
        )
        try insertFolder(
            id: childFolderId,
            parentFolderId: folderId,
            rootFolderId: rootFolderId,
            into: folderStore
        )

        let unavailableTrack = makeTrack(
            folderId: folderId,
            rootFolderId: rootFolderId,
            fileSize: 100,
            isAvailable: false
        )
        let directTrack = makeTrack(
            folderId: folderId,
            rootFolderId: rootFolderId,
            fileSize: 200
        )
        let childTrack = makeTrack(
            folderId: childFolderId,
            rootFolderId: rootFolderId,
            fileSize: 1_000
        )
        var deletedTrack = makeTrack(
            folderId: folderId,
            rootFolderId: rootFolderId,
            fileSize: 1_000
        )
        deletedTrack.isDeleted = true

        try trackStore.insert(unavailableTrack)
        try trackStore.insert(directTrack)
        try trackStore.insert(childTrack)
        try trackStore.insert(deletedTrack)
        try metadataStore.upsert(makeMetadata(trackId: unavailableTrack.id, duration: 120))
        try metadataStore.upsert(makeMetadata(trackId: directTrack.id, duration: 60))
        try metadataStore.upsert(makeMetadata(trackId: childTrack.id, duration: 600))
        try metadataStore.upsert(makeMetadata(trackId: deletedTrack.id, duration: 600))

        let summary = try await provider.summaryForFolder(folderId: folderId)

        XCTAssertEqual(summary.trackCount, 2)
        XCTAssertEqual(summary.totalDuration, 180)
        XCTAssertEqual(summary.totalFileSize, 300)
        XCTAssertEqual(summary.unknownDurationCount, 0)
        XCTAssertEqual(summary.unknownFileSizeCount, 0)
        XCTAssertEqual(
            TrackCollectionSummaryFormatter.string(from: summary),
            "2 трека • 3 мин • \(ByteCountFormatter.string(fromByteCount: 300, countStyle: .file))"
        )
    }

    func testFolderSummaryKeepsKnownTotalsWhenOtherValuesAreMissing() async throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let folderStore = SQLiteFolderStore(executor: executor)
        let trackStore = SQLiteTrackStore(executor: executor)
        let metadataStore = SQLiteTrackMetadataStore(executor: executor)
        let provider = SQLiteTrackCollectionSummaryProvider(executor: executor)
        let folderId = UUID()

        try insertFolder(id: folderId, into: folderStore, isRoot: true)

        let unknownTrack = makeTrack(folderId: folderId, fileSize: nil)
        let knownTrack = makeTrack(folderId: folderId, fileSize: 200)
        try trackStore.insert(unknownTrack)
        try trackStore.insert(knownTrack)
        try metadataStore.upsert(makeMetadata(trackId: unknownTrack.id, duration: 60))
        try metadataStore.upsert(makeMetadata(trackId: knownTrack.id, duration: 60))

        let summary = try await provider.summaryForFolder(folderId: folderId)

        XCTAssertEqual(summary.trackCount, 2)
        XCTAssertEqual(summary.totalDuration, 120)
        XCTAssertEqual(summary.totalFileSize, 200)
        XCTAssertEqual(summary.unknownDurationCount, 0)
        XCTAssertEqual(summary.unknownFileSizeCount, 1)
        XCTAssertEqual(
            TrackCollectionSummaryFormatter.string(from: summary),
            "2 трека • 2 мин"
        )
    }

    func testFolderSummaryTreatsZeroFileSizeAsKnownValue() async throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let folderStore = SQLiteFolderStore(executor: executor)
        let trackStore = SQLiteTrackStore(executor: executor)
        let provider = SQLiteTrackCollectionSummaryProvider(executor: executor)
        let folderId = UUID()

        try insertFolder(id: folderId, into: folderStore, isRoot: true)
        try trackStore.insert(makeTrack(folderId: folderId, fileSize: 0))

        let summary = try await provider.summaryForFolder(folderId: folderId)

        XCTAssertEqual(summary.trackCount, 1)
        XCTAssertEqual(summary.totalFileSize, 0)
        XCTAssertEqual(summary.unknownFileSizeCount, 0)
    }

    func testSummaryBecomesCompleteAfterFileSizeIsUpdated() async throws {
        let database = try makeDatabase()
        let store = try LibraryDatabaseStore(database: database)
        let provider = try SQLiteTrackCollectionSummaryProvider(database: database)
        let rootFolderId = UUID()
        let trackId = UUID()
        let fileDate = Date(timeIntervalSince1970: 1_000)

        try store.upsertRootFolder(id: rootFolderId, name: "Музыка")
        try store.upsertLibraryTrack(
            id: trackId,
            fileName: "Трек.mp3",
            relativePath: "Трек.mp3",
            folderId: rootFolderId,
            rootFolderId: rootFolderId,
            fileDate: fileDate,
            shouldUpdateFileSize: true
        )

        let incompleteSummary = try await provider.summaryForFolder(folderId: rootFolderId)
        XCTAssertEqual(incompleteSummary.unknownFileSizeCount, 1)
        XCTAssertFalse(incompleteSummary.hasCompleteFileSize)

        try store.upsertLibraryTrack(
            id: trackId,
            fileName: "Трек.mp3",
            relativePath: "Трек.mp3",
            folderId: rootFolderId,
            rootFolderId: rootFolderId,
            fileDate: fileDate,
            fileSize: 2_048,
            shouldUpdateFileSize: true
        )

        let completeSummary = try await provider.summaryForFolder(folderId: rootFolderId)
        XCTAssertEqual(completeSummary.totalFileSize, 2_048)
        XCTAssertEqual(completeSummary.unknownFileSizeCount, 0)
        XCTAssertTrue(completeSummary.hasCompleteFileSize)
    }

    func testRepeatedLibraryTrackSaveKeepsKnownFileSize() throws {
        let database = try makeDatabase()
        let store = try LibraryDatabaseStore(database: database)
        let rootFolderId = UUID()
        let trackId = UUID()
        let fileDate = Date(timeIntervalSince1970: 1_000)

        try store.upsertRootFolder(id: rootFolderId, name: "Музыка")
        try store.upsertLibraryTrack(
            id: trackId,
            fileName: "Трек.mp3",
            relativePath: "Трек.mp3",
            folderId: rootFolderId,
            rootFolderId: rootFolderId,
            fileDate: fileDate,
            fileSize: 4_096,
            shouldUpdateFileSize: true
        )
        try store.upsertLibraryTrack(
            id: trackId,
            fileName: "Переименованный трек.mp3",
            relativePath: "Переименованный трек.mp3",
            folderId: rootFolderId,
            rootFolderId: rootFolderId,
            fileDate: fileDate
        )

        XCTAssertEqual(try store.fetchLibraryTrack(id: trackId)?.fileSize, 4_096)
    }

    func testUndownloadedICloudFileDoesNotReceiveFalseZeroFileSize() {
        XCTAssertNil(
            LibraryFileSizeResolver.resolvedFileSize(
                fileSize: 4_096,
                isUbiquitousItem: true,
                downloadingStatus: .notDownloaded
            )
        )
        XCTAssertEqual(
            LibraryFileSizeResolver.resolvedFileSize(
                fileSize: 0,
                isUbiquitousItem: false,
                downloadingStatus: nil
            ),
            0
        )
    }

    func testTrackListSummaryIsEmptyForTrackListWithoutRows() async throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let trackListStore = SQLiteTrackListStore(executor: executor)
        let provider = SQLiteTrackCollectionSummaryProvider(executor: executor)
        let trackListId = UUID()

        try insertTrackList(id: trackListId, into: trackListStore)

        let summary = try await provider.summaryForTrackList(trackListId: trackListId)

        XCTAssertEqual(summary.trackCount, 0)
        XCTAssertNil(summary.totalDuration)
        XCTAssertNil(summary.totalFileSize)
        XCTAssertEqual(summary.unknownDurationCount, 0)
        XCTAssertEqual(summary.unknownFileSizeCount, 0)
    }

    func testTrackListSummaryCountsDuplicateRowsAndUsesCurrentDuration() async throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let trackStore = SQLiteTrackStore(executor: executor)
        let metadataStore = SQLiteTrackMetadataStore(executor: executor)
        let trackListStore = SQLiteTrackListStore(executor: executor)
        let trackListTrackStore = SQLiteTrackListTrackStore(executor: executor)
        let provider = SQLiteTrackCollectionSummaryProvider(executor: executor)
        let trackListId = UUID()
        let track = makeTrack(fileSize: 1_024)

        try trackStore.insert(track)
        try metadataStore.upsert(makeMetadata(trackId: track.id, duration: 120))
        try insertTrackList(id: trackListId, into: trackListStore)
        try trackListTrackStore.insert(
            makeTrackListTrack(
                trackListId: trackListId,
                trackId: track.id,
                position: 0,
                durationSnapshot: 30
            )
        )
        try trackListTrackStore.insert(
            makeTrackListTrack(
                trackListId: trackListId,
                trackId: track.id,
                position: 1,
                durationSnapshot: 30
            )
        )

        let summary = try await provider.summaryForTrackList(trackListId: trackListId)

        XCTAssertEqual(summary.trackCount, 2)
        XCTAssertEqual(summary.totalDuration, 240)
        XCTAssertEqual(summary.totalFileSize, 2_048)
        XCTAssertEqual(summary.unknownDurationCount, 0)
        XCTAssertEqual(summary.unknownFileSizeCount, 0)
    }

    func testTrackListSummaryUsesSnapshotAndMarksMissingTracksAndSizesUnknown() async throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let trackStore = SQLiteTrackStore(executor: executor)
        let trackListStore = SQLiteTrackListStore(executor: executor)
        let trackListTrackStore = SQLiteTrackListTrackStore(executor: executor)
        let provider = SQLiteTrackCollectionSummaryProvider(executor: executor)
        let trackListId = UUID()
        let trackWithoutSize = makeTrack(fileSize: nil)
        let missingTrackId = UUID()
        let trackWithoutDuration = makeTrack(fileSize: 200)

        try trackStore.insert(trackWithoutSize)
        try trackStore.insert(trackWithoutDuration)
        try insertTrackList(id: trackListId, into: trackListStore)
        try trackListTrackStore.insert(
            makeTrackListTrack(
                trackListId: trackListId,
                trackId: trackWithoutSize.id,
                position: 0,
                durationSnapshot: 50
            )
        )
        try trackListTrackStore.insert(
            makeTrackListTrack(
                trackListId: trackListId,
                trackId: missingTrackId,
                position: 1,
                durationSnapshot: 70
            )
        )
        try trackListTrackStore.insert(
            makeTrackListTrack(
                trackListId: trackListId,
                trackId: trackWithoutDuration.id,
                position: 2,
                durationSnapshot: nil
            )
        )

        let summary = try await provider.summaryForTrackList(trackListId: trackListId)

        XCTAssertEqual(summary.trackCount, 3)
        XCTAssertEqual(summary.totalDuration, 120)
        XCTAssertEqual(summary.totalFileSize, 200)
        XCTAssertEqual(summary.unknownDurationCount, 1)
        XCTAssertEqual(summary.unknownFileSizeCount, 2)
    }

    func testTrackListSummaryDoesNotDependOnRowsOrder() async throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let trackStore = SQLiteTrackStore(executor: executor)
        let metadataStore = SQLiteTrackMetadataStore(executor: executor)
        let trackListStore = SQLiteTrackListStore(executor: executor)
        let trackListTrackStore = SQLiteTrackListTrackStore(executor: executor)
        let provider = SQLiteTrackCollectionSummaryProvider(executor: executor)
        let trackListId = UUID()
        let firstTrack = makeTrack(fileSize: 100)
        let secondTrack = makeTrack(fileSize: 200)

        try trackStore.insert(firstTrack)
        try trackStore.insert(secondTrack)
        try metadataStore.upsert(makeMetadata(trackId: firstTrack.id, duration: 60))
        try metadataStore.upsert(makeMetadata(trackId: secondTrack.id, duration: 120))
        try insertTrackList(id: trackListId, into: trackListStore)

        let firstRow = makeTrackListTrack(
            trackListId: trackListId,
            trackId: firstTrack.id,
            position: 0,
            durationSnapshot: 10
        )
        let secondRow = makeTrackListTrack(
            trackListId: trackListId,
            trackId: secondTrack.id,
            position: 1,
            durationSnapshot: 20
        )
        try trackListTrackStore.replaceAll([firstRow, secondRow], forTrackListId: trackListId)
        let initialSummary = try await provider.summaryForTrackList(trackListId: trackListId)

        var reorderedFirstRow = firstRow
        reorderedFirstRow.position = 1
        var reorderedSecondRow = secondRow
        reorderedSecondRow.position = 0
        try trackListTrackStore.replaceAll(
            [reorderedSecondRow, reorderedFirstRow],
            forTrackListId: trackListId
        )

        let reorderedSummary = try await provider.summaryForTrackList(trackListId: trackListId)

        XCTAssertEqual(reorderedSummary, initialSummary)
    }

    /// Создаёт краткую статистику для тестов форматтера без неизвестных значений.
    private func makeSummary(
        count: Int,
        duration: TimeInterval? = nil,
        fileSize: Int64? = nil
    ) -> TrackCollectionSummary {
        TrackCollectionSummary(
            trackCount: count,
            totalDuration: duration,
            totalFileSize: fileSize,
            unknownDurationCount: 0,
            unknownFileSizeCount: 0
        )
    }

    /// Открывает отдельную временную SQLite-базу с актуальными миграциями приложения.
    private func makeDatabase() throws -> AppDatabase {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrackCollectionSummaryTests-\(UUID().uuidString)", isDirectory: true)
        let databaseURL = directory.appendingPathComponent("TrackList.sqlite")
        let database = AppDatabase(
            location: DatabaseLocation(databaseURL: databaseURL),
            migrator: DatabaseMigrator(migrations: DatabaseMigration.all)
        )

        try database.open()
        self.database = database
        self.databaseDirectory = directory
        return database
    }

    /// Сохраняет папку, необходимую для проверки внешнего ключа tracks.folder_id.
    private func insertFolder(
        id: UUID,
        parentFolderId: UUID? = nil,
        rootFolderId: UUID? = nil,
        into store: SQLiteFolderStore,
        isRoot: Bool = false
    ) throws {
        let now = Date()
        try store.upsert(
            FolderDatabaseModel(
                id: id,
                parentFolderId: parentFolderId,
                rootFolderId: rootFolderId,
                name: "Папка",
                relativePath: id.uuidString,
                bookmarkBase64: nil,
                isRoot: isRoot,
                isAvailable: true,
                createdAt: now,
                updatedAt: now,
                sortOrder: nil,
                lastScannedAt: nil,
                trackSortMode: nil
            )
        )
    }

    /// Создаёт строку tracks с управляемыми размером и принадлежностью папке.
    private func makeTrack(
        folderId: UUID? = nil,
        rootFolderId: UUID? = nil,
        fileSize: Int64? = nil,
        isAvailable: Bool = true
    ) -> TrackDatabaseModel {
        let now = Date()
        return TrackDatabaseModel(
            id: UUID(),
            source: .library,
            folderId: folderId,
            rootFolderId: rootFolderId,
            fileName: "Трек.mp3",
            relativePath: UUID().uuidString + ".mp3",
            fileExtension: "mp3",
            fileSize: fileSize,
            fileDate: now,
            importedAt: now,
            updatedAt: now,
            bookmarkBase64: nil,
            assetURLString: nil,
            isAvailable: isAvailable,
            isDeleted: false
        )
    }

    /// Создаёт сохранённую metadata с указанной актуальной длительностью.
    private func makeMetadata(
        trackId: UUID,
        duration: Double?
    ) -> TrackMetadataDatabaseModel {
        TrackMetadataDatabaseModel(
            trackId: trackId,
            title: nil,
            artist: nil,
            album: nil,
            albumArtist: nil,
            label: nil,
            genre: nil,
            year: nil,
            trackNumber: nil,
            discNumber: nil,
            bpm: nil,
            keySignature: nil,
            comment: nil,
            duration: duration,
            bitrate: nil,
            sampleRate: nil,
            channelCount: nil,
            metadataUpdatedAt: Date()
        )
    }

    /// Сохраняет активный треклист, необходимый для внешнего ключа его строк.
    private func insertTrackList(
        id: UUID,
        into store: SQLiteTrackListStore
    ) throws {
        let now = Date()
        try store.upsert(
            TrackListDatabaseModel(
                id: id,
                name: "Тестовый треклист",
                createdAt: now,
                updatedAt: now,
                sortOrder: nil,
                isDeleted: false
            )
        )
    }

    /// Создаёт строку треклиста с сохранённой длительностью на случай отсутствия актуальной metadata.
    private func makeTrackListTrack(
        trackListId: UUID,
        trackId: UUID,
        position: Int,
        durationSnapshot: Double?
    ) -> TrackListTrackDatabaseModel {
        TrackListTrackDatabaseModel(
            id: UUID(),
            trackListId: trackListId,
            trackId: trackId,
            position: position,
            sourceSnapshot: .library,
            titleSnapshot: nil,
            artistSnapshot: nil,
            albumSnapshot: nil,
            durationSnapshot: durationSnapshot,
            fileNameSnapshot: "Трек.mp3",
            assetURLSnapshot: nil,
            isAvailableSnapshot: true,
            createdAt: Date()
        )
    }
}
