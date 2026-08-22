//
//  SQLiteDatabaseFailureTests.swift
//  TrackList
//
//  Проверки rollback, ограничений и отказов SQLite-операций.
//
//  Created by Pavel Fomin on 22.08.2026.
//

import XCTest
@testable import TrackList

final class SQLiteDatabaseFailureTests: SQLiteDatabaseTestCase {
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

    func testLibrarySyncCommitRollsBackWholeSnapshotWhenLaterTransactionStepFails() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = LibraryDatabaseStore(executor: executor)
        let rootFolderId = UUID()
        let trackId = UUID()
        let record = LibrarySyncTrackRecord(
            id: trackId,
            fileName: "sync.mp3",
            relativePath: "sync.mp3",
            folderId: rootFolderId,
            rootFolderId: rootFolderId,
            fileDate: Date(timeIntervalSince1970: 100),
            fileSize: 128,
            bookmarkBase64: "sync-bookmark"
        )

        XCTAssertThrowsError(
            try executor.transaction { _ in
                try store.applyLibrarySync(records: [record], removingTrackIDs: [])
                // Искусственная ошибка после записи track и bookmark проверяет именно границу общего commit.
                throw ExpectedRollbackError.rollback
            }
        )

        XCTAssertNil(try store.fetchLibraryTrack(id: trackId))
        XCTAssertNil(try store.trackBookmark(id: trackId))
        XCTAssertTrue(try store.fetchRootFolders().isEmpty)
    }

    func testTrackListKindConstraintRejectsUnknownValue() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let createdAt = Date(timeIntervalSince1970: 100)

        XCTAssertThrowsError(
            try executor.write { database in
                let statement = try database.prepare(
                    """
                    INSERT INTO tracklists (
                        id, name, kind, created_at, updated_at, sort_order, is_deleted
                    ) VALUES (?, ?, ?, ?, ?, ?, ?);
                    """
                )
                try statement.bind(UUID(), at: 1)
                try statement.bind("Invalid", at: 2)
                try statement.bind("unsupported", at: 3)
                try statement.bind(createdAt, at: 4)
                try statement.bind(createdAt, at: 5)
                try statement.bind(nil as Int?, at: 6)
                try statement.bind(false, at: 7)
                try statement.execute()
            }
        )
    }

    func testTrackListsOrderingStoreRollsBackOrderWhenSettingsWriteFails() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let trackListStore = SQLiteTrackListStore(executor: executor)
        let regularA = try store.createTrackList(
            id: UUID(),
            name: "A",
            kind: .regular,
            createdAt: Date(timeIntervalSince1970: 100),
            tracks: []
        )
        let regularB = try store.createTrackList(
            id: UUID(),
            name: "B",
            kind: .regular,
            createdAt: Date(timeIntervalSince1970: 200),
            tracks: []
        )
        let favorites = try store.createTrackList(
            id: UUID(),
            name: "Favorites",
            kind: .favorites,
            createdAt: Date(timeIntervalSince1970: 300),
            tracks: []
        )
        try store.updateTrackListsOrder([regularA.id, regularB.id])
        let initialRegularOrders = [
            try trackListStore.fetch(id: regularA.id)?.sortOrder,
            try trackListStore.fetch(id: regularB.id)?.sortOrder
        ]
        let settingsStore = FailingTrackListsOrderingSettingsStore()
        let orderingStore = TrackListsOrderingDatabaseStore(
            executor: executor,
            trackListsStore: store,
            libraryViewSettingsStore: settingsStore
        )

        XCTAssertThrowsError(
            try orderingStore.persist(
                sortMode: .name,
                orderedTrackListIDs: [favorites.id, regularB.id, regularA.id]
            )
        ) { error in
            guard let appError = error as? AppError,
                  case .trackListSaveFailed = appError
            else {
                return XCTFail("Ожидалась ошибка сохранения общей master-транзакции")
            }
        }

        XCTAssertEqual(
            [
                try trackListStore.fetch(id: regularA.id)?.sortOrder,
                try trackListStore.fetch(id: regularB.id)?.sortOrder
            ],
            initialRegularOrders
        )
    }

    private enum ExpectedRollbackError: Error {
        case rollback
    }
}

// Имитирует сбой второй записи общей master-команды после изменения порядка треклистов.
private final class FailingTrackListsOrderingSettingsStore: LibraryViewSettingsDatabaseReading, LibraryViewSettingsDatabaseWriting {
    private let model = LibraryViewSettingsDatabaseModel(
        id: 1,
        sortMode: "fileDateDesc",
        purchasedITunesSortMode: "titleAsc",
        trackListsSortMode: nil,
        groupMode: "none",
        showTrackListBadges: true,
        showUnavailableTracks: false,
        showFileFormat: true,
        showPurchasedITunesSource: true,
        libraryRootDisplayMode: "folders",
        lastOpenedFolderId: nil,
        updatedAt: Date(timeIntervalSince1970: 100)
    )

    func fetch() throws -> LibraryViewSettingsDatabaseModel? {
        model
    }

    func insert(_ model: LibraryViewSettingsDatabaseModel) throws {}
    func update(_ model: LibraryViewSettingsDatabaseModel) throws {}

    func upsert(_ model: LibraryViewSettingsDatabaseModel) throws {
        throw TrackListsOrderingSettingsWriteError.failed
    }

    func delete() throws {}
}

private enum TrackListsOrderingSettingsWriteError: Error {
    case failed
}
