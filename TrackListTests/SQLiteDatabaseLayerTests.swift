//
//  SQLiteDatabaseLayerTests.swift
//  TrackListTests
//
//  Минимальные проверки типобезопасного SQLite-слоя.
//
//  Created by Codex on 04.07.2026.
//

import XCTest
@testable import TrackList

final class SQLiteDatabaseLayerTests: XCTestCase {
    private var database: AppDatabase?
    private var databaseDirectory: URL?

    override func tearDownWithError() throws {
        // Закрываем временную базу до удаления WAL/SHM-файлов.
        try database?.close()
        database = nil

        if let databaseDirectory {
            try? FileManager.default.removeItem(at: databaseDirectory)
        }
        databaseDirectory = nil

        try super.tearDownWithError()
    }

    func testTrackInsertFetchUpsertDelete() throws {
        let database = try makeDatabase()
        let store = try SQLiteTrackStore(database: database)
        let trackId = UUID()
        let now = Date()

        let initialTrack = TrackDatabaseModel(
            id: trackId,
            source: .library,
            folderId: nil,
            rootFolderId: nil,
            fileName: "initial.mp3",
            relativePath: "initial.mp3",
            fileExtension: "mp3",
            fileSize: 128,
            fileDate: now,
            importedAt: now,
            updatedAt: now,
            bookmarkBase64: nil,
            assetURLString: nil,
            isAvailable: true,
            isDeleted: false
        )

        try store.insert(initialTrack)
        XCTAssertEqual(try store.fetch(id: trackId)?.fileName, "initial.mp3")

        var updatedTrack = initialTrack
        updatedTrack.fileName = "updated.mp3"
        updatedTrack.updatedAt = now.addingTimeInterval(1)
        try store.upsert(updatedTrack)

        XCTAssertEqual(try store.fetch(id: trackId)?.fileName, "updated.mp3")

        try store.delete(id: trackId)
        XCTAssertNil(try store.fetch(id: trackId))
    }

    func testTransactionRollsBackInsertedTrack() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = SQLiteTrackStore(executor: executor)
        let track = makeTrack(fileName: "rollback.mp3")

        XCTAssertThrowsError(
            try executor.transaction { _ in
                try store.insert(track)
                throw ExpectedRollbackError.rollback
            }
        )

        XCTAssertNil(try store.fetch(id: track.id))
    }

    func testPlayerQueueReplaceAll() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let trackStore = SQLiteTrackStore(executor: executor)
        let queueStore = SQLitePlayerQueueStore(executor: executor)
        let firstTrack = makeTrack(fileName: "first.mp3")
        let secondTrack = makeTrack(fileName: "second.mp3")
        let now = Date()

        try trackStore.insert(firstTrack)
        try trackStore.insert(secondTrack)

        let firstItem = PlayerQueueItemDatabaseModel(
            id: UUID(),
            trackId: firstTrack.id,
            position: 0,
            sourceSnapshot: .library,
            titleSnapshot: "First",
            artistSnapshot: nil,
            albumSnapshot: nil,
            durationSnapshot: 10,
            fileNameSnapshot: firstTrack.fileName,
            assetURLSnapshot: nil,
            isAvailableSnapshot: true,
            createdAt: now
        )

        let secondItem = PlayerQueueItemDatabaseModel(
            id: UUID(),
            trackId: secondTrack.id,
            position: 1,
            sourceSnapshot: .library,
            titleSnapshot: "Second",
            artistSnapshot: nil,
            albumSnapshot: nil,
            durationSnapshot: 20,
            fileNameSnapshot: secondTrack.fileName,
            assetURLSnapshot: nil,
            isAvailableSnapshot: true,
            createdAt: now
        )

        try queueStore.replaceAll([firstItem, secondItem])
        XCTAssertEqual(try queueStore.fetchAll().map(\.position), [0, 1])

        var replacementItem = secondItem
        replacementItem.position = 0
        try queueStore.replaceAll([replacementItem])

        let queue = try queueStore.fetchAll()
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.first?.trackId, secondTrack.id)
        XCTAssertEqual(queue.first?.position, 0)
    }

    private func makeDatabase() throws -> AppDatabase {
        let directory = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("SQLiteDatabaseLayerTests-\(UUID().uuidString)", isDirectory: true)
        let databaseURL = directory.appendingPathComponent("TrackList.sqlite")
        let database = AppDatabase(
            location: DatabaseLocation(databaseURL: databaseURL),
            migrator: DatabaseMigrator(migrations: [
                .initialSchema,
                .initialTables
            ])
        )

        try database.open()

        self.database = database
        self.databaseDirectory = directory

        return database
    }

    private func makeTrack(fileName: String) -> TrackDatabaseModel {
        let now = Date()

        // Тестовый трек не привязан к папке, чтобы проверять только таблицу tracks.
        return TrackDatabaseModel(
            id: UUID(),
            source: .library,
            folderId: nil,
            rootFolderId: nil,
            fileName: fileName,
            relativePath: fileName,
            fileExtension: "mp3",
            fileSize: nil,
            fileDate: now,
            importedAt: now,
            updatedAt: now,
            bookmarkBase64: nil,
            assetURLString: nil,
            isAvailable: true,
            isDeleted: false
        )
    }

    private enum ExpectedRollbackError: Error {
        case rollback
    }
}
