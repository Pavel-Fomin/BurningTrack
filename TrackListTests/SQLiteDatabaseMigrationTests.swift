//
//  SQLiteDatabaseMigrationTests.swift
//  TrackList
//
//  Проверки миграций SQLite-схемы и сохранности данных.
//
//  Created by Pavel Fomin on 22.08.2026.
//

import XCTest
@testable import TrackList

final class SQLiteDatabaseMigrationTests: SQLiteDatabaseTestCase {
    func testPlayerExternalTrackIdsMigrationPreservesDataIndexesAndQueueReference() throws {
        // Создаём базу на схеме до миграции 017, чтобы проверить реальный upgrade существующих данных.
        let legacyMigrations = DatabaseMigration.all.filter {
            $0.identifier != DatabaseMigration.playerQueueAndStateAllowExternalTrackIds.identifier
        }
        let legacyDatabase = try makeDatabase(migrations: legacyMigrations)
        let legacyExecutor = try legacyDatabase.databaseExecutor()
        let trackStore = SQLiteTrackStore(executor: legacyExecutor)
        let queueStore = SQLitePlayerQueueStore(executor: legacyExecutor)
        let stateStore = SQLitePlayerStateStore(executor: legacyExecutor)
        let firstTrack = makeTrack(fileName: "MigrationFirst.mp3")
        var secondTrack = makeTrack(fileName: "MigrationImported.m4a")
        secondTrack.source = .imported
        let firstQueueItem = makePlayerQueueItem(
            trackId: firstTrack.id,
            position: 0,
            source: .library,
            title: "Migration First",
            assetURL: nil
        )
        let secondQueueItem = makePlayerQueueItem(
            trackId: secondTrack.id,
            position: 1,
            source: .imported,
            title: "Migration Imported",
            assetURL: URL(string: "file:///tmp/MigrationImported.m4a")
        )
        let state = PlayerStateDatabaseModel(
            id: 1,
            currentQueueItemId: secondQueueItem.id,
            currentTrackId: secondTrack.id,
            contextType: .libraryCollection,
            contextId: nil,
            collectionCategory: "albums",
            collectionValue: "Migration Album",
            collectionArtistKey: "Migration Artist",
            playbackTime: 25,
            duration: 180,
            isPlaying: false,
            repeatMode: .all,
            shuffleEnabled: true,
            updatedAt: Date(timeIntervalSince1970: 300)
        )

        try trackStore.insert(firstTrack)
        try trackStore.insert(secondTrack)
        try queueStore.replaceAll([firstQueueItem, secondQueueItem])
        try stateStore.upsert(state)

        let databaseURL = try XCTUnwrap(legacyDatabase.databaseURL)
        try legacyDatabase.close()

        // Повторное открытие той же базы применяет только новую миграцию 017.
        let migratedDatabase = AppDatabase(
            location: DatabaseLocation(databaseURL: databaseURL),
            migrator: DatabaseMigrator(migrations: DatabaseMigration.all)
        )
        try migratedDatabase.open()
        database = migratedDatabase

        let migratedExecutor = try migratedDatabase.databaseExecutor()
        let migratedQueueStore = SQLitePlayerQueueStore(executor: migratedExecutor)
        let migratedStateStore = SQLitePlayerStateStore(executor: migratedExecutor)
        let restoredQueue = try migratedQueueStore.fetchAll()
        let restoredState = try XCTUnwrap(migratedStateStore.fetch())

        XCTAssertEqual(restoredQueue, [firstQueueItem, secondQueueItem])
        XCTAssertEqual(restoredState, state)

        // player_queue больше не требует строку tracks для внешнего track_id.
        let queueForeignKeys: [String] = try migratedExecutor.fetchAll(
            "PRAGMA foreign_key_list(player_queue);",
            map: { try $0.requiredString(at: 3) }
        )
        XCTAssertTrue(queueForeignKeys.isEmpty)

        // player_state сохраняет только связь текущего элемента с очередью.
        let stateForeignKeys: [String] = try migratedExecutor.fetchAll(
            "PRAGMA foreign_key_list(player_state);",
            map: { row in
                let sourceColumn = try row.requiredString(at: 3)
                let targetTable = try row.requiredString(at: 2)
                let targetColumn = try row.requiredString(at: 4)
                let deleteAction = try row.requiredString(at: 6)
                return "\(sourceColumn)->\(targetTable).\(targetColumn):\(deleteAction)"
            }
        )
        XCTAssertEqual(
            stateForeignKeys,
            ["current_queue_item_id->player_queue.id:SET NULL"]
        )

        // После перестройки должны сохраниться все именованные индексы очереди.
        let queueIndexes = Set(
            try migratedExecutor.fetchAll(
                "PRAGMA index_list(player_queue);",
                map: { try $0.requiredString(at: 1) }
            )
        )
        XCTAssertTrue(queueIndexes.contains("idx_player_queue_unique_position"))
        XCTAssertTrue(queueIndexes.contains("idx_player_queue_position"))
        XCTAssertTrue(queueIndexes.contains("idx_player_queue_track_id"))

        let foreignKeyViolations: [String] = try migratedExecutor.fetchAll(
            "PRAGMA foreign_key_check;",
            map: { try $0.requiredString(at: 0) }
        )
        XCTAssertTrue(foreignKeyViolations.isEmpty)
    }

    func testTrackListKindMigrationAddsRegularKindToExistingRows() throws {
        // Создаём базу до миграции 019, чтобы проверить обновление уже сохранённого треклиста.
        let legacyMigrations = DatabaseMigration.all.filter {
            $0.identifier != DatabaseMigration.trackListKind.identifier &&
            $0.identifier != DatabaseMigration.trackListFavoritesUniqueness.identifier
        }
        let legacyDatabase = try makeDatabase(migrations: legacyMigrations)
        let legacyExecutor = try legacyDatabase.databaseExecutor()
        let trackListId = UUID()
        let createdAt = Date(timeIntervalSince1970: 100)

        try legacyExecutor.write { database in
            let statement = try database.prepare(
                """
                INSERT INTO tracklists (
                    id, name, created_at, updated_at, sort_order, is_deleted
                ) VALUES (?, ?, ?, ?, ?, ?);
                """
            )
            try statement.bind(trackListId, at: 1)
            try statement.bind("Legacy", at: 2)
            try statement.bind(createdAt, at: 3)
            try statement.bind(createdAt, at: 4)
            try statement.bind(nil as Int?, at: 5)
            try statement.bind(false, at: 6)
            try statement.execute()
        }

        let databaseURL = try XCTUnwrap(legacyDatabase.databaseURL)
        try legacyDatabase.close()

        let migratedDatabase = AppDatabase(
            location: DatabaseLocation(databaseURL: databaseURL),
            migrator: DatabaseMigrator(migrations: DatabaseMigration.all)
        )
        try migratedDatabase.open()
        database = migratedDatabase

        let migratedExecutor = try migratedDatabase.databaseExecutor()
        let migratedStore = SQLiteTrackListStore(executor: migratedExecutor)
        XCTAssertEqual(try migratedStore.fetch(id: trackListId)?.kind, .regular)

        let migrationCount = try appliedMigrationCount(
            identifier: DatabaseMigration.trackListKind.identifier,
            executor: migratedExecutor
        )
        XCTAssertEqual(migrationCount, 1)

        try migratedDatabase.close()

        // Повторное открытие не применяет миграцию второй раз и сохраняет назначение записи.
        let reopenedDatabase = AppDatabase(
            location: DatabaseLocation(databaseURL: databaseURL),
            migrator: DatabaseMigrator(migrations: DatabaseMigration.all)
        )
        try reopenedDatabase.open()
        database = reopenedDatabase

        let reopenedExecutor = try reopenedDatabase.databaseExecutor()
        let reopenedStore = SQLiteTrackListStore(executor: reopenedExecutor)
        XCTAssertEqual(try reopenedStore.fetch(id: trackListId)?.kind, .regular)

        let reopenedMigrationCount = try appliedMigrationCount(
            identifier: DatabaseMigration.trackListKind.identifier,
            executor: reopenedExecutor
        )
        XCTAssertEqual(reopenedMigrationCount, 1)
    }

    func testTrackListFavoritesUniquenessMigrationNormalizesHistoricDuplicates() throws {
        let legacyMigrations = DatabaseMigration.all.filter {
            $0.identifier != DatabaseMigration.trackListFavoritesUniqueness.identifier
        }
        let legacyDatabase = try makeDatabase(migrations: legacyMigrations)
        let legacyExecutor = try legacyDatabase.databaseExecutor()
        let legacyStore = SQLiteTrackListStore(executor: legacyExecutor)
        let primaryID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let duplicateID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))

        try legacyStore.insert(
            makeTrackListDatabaseModel(
                id: primaryID,
                name: "Первичная историческая запись",
                kind: .favorites,
                createdAt: Date(timeIntervalSince1970: 100),
                isDeleted: false
            )
        )
        try legacyStore.insert(
            makeTrackListDatabaseModel(
                id: duplicateID,
                name: "Дубликат исторической записи",
                kind: .favorites,
                createdAt: Date(timeIntervalSince1970: 200),
                isDeleted: false
            )
        )

        let databaseURL = try XCTUnwrap(legacyDatabase.databaseURL)
        try legacyDatabase.close()

        let migratedDatabase = AppDatabase(
            location: DatabaseLocation(databaseURL: databaseURL),
            migrator: DatabaseMigrator(migrations: DatabaseMigration.all)
        )
        try migratedDatabase.open()
        database = migratedDatabase

        let migratedExecutor = try migratedDatabase.databaseExecutor()
        let migratedStore = SQLiteTrackListStore(executor: migratedExecutor)

        XCTAssertFalse(try XCTUnwrap(migratedStore.fetch(id: primaryID)).isDeleted)
        XCTAssertTrue(try XCTUnwrap(migratedStore.fetch(id: duplicateID)).isDeleted)
        XCTAssertEqual(
            try appliedMigrationCount(
                identifier: DatabaseMigration.trackListFavoritesUniqueness.identifier,
                executor: migratedExecutor
            ),
            1
        )

        try migratedDatabase.close()

        let reopenedDatabase = AppDatabase(
            location: DatabaseLocation(databaseURL: databaseURL),
            migrator: DatabaseMigrator(migrations: DatabaseMigration.all)
        )
        try reopenedDatabase.open()
        database = reopenedDatabase

        let reopenedExecutor = try reopenedDatabase.databaseExecutor()
        let reopenedStore = SQLiteTrackListStore(executor: reopenedExecutor)
        XCTAssertFalse(try XCTUnwrap(reopenedStore.fetch(id: primaryID)).isDeleted)
        XCTAssertTrue(try XCTUnwrap(reopenedStore.fetch(id: duplicateID)).isDeleted)
        XCTAssertEqual(
            try appliedMigrationCount(
                identifier: DatabaseMigration.trackListFavoritesUniqueness.identifier,
                executor: reopenedExecutor
            ),
            1
        )
    }

    private func appliedMigrationCount(
        identifier: String,
        executor: DatabaseExecutor
    ) throws -> Int {
        try executor.read { database in
            let statement = try database.prepare(
                "SELECT COUNT(*) FROM schema_migrations WHERE identifier = ?;"
            )
            try statement.bind(identifier, at: 1)

            guard try statement.step() == .row else {
                throw DatabaseError.missingRequiredColumn(name: "migration_count")
            }

            return try statement.rowReader().requiredInt(at: 0)
        }
    }

    private func makePlayerQueueItem(
        trackId: UUID,
        position: Int,
        source: DatabaseTrackSource,
        title: String,
        assetURL: URL?
    ) -> PlayerQueueItemDatabaseModel {
        PlayerQueueItemDatabaseModel(
            id: UUID(),
            trackId: trackId,
            position: position,
            sourceSnapshot: source,
            titleSnapshot: title,
            artistSnapshot: "Artist",
            albumSnapshot: "Album",
            durationSnapshot: 180,
            fileNameSnapshot: "\(title).m4a",
            assetURLSnapshot: assetURL?.absoluteString,
            isAvailableSnapshot: true,
            createdAt: Date(timeIntervalSince1970: 300)
        )
    }
}
