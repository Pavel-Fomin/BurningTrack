//
//  SQLiteDatabaseLayerTests.swift
//  TrackListTests
//
//  Минимальные проверки типобезопасного SQLite-слоя.
//
//  Created by Codex on 04.07.2026.
//

import XCTest
import Combine
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

    func testTrackInsertFetchUpsertMarkDeleted() throws {
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

        try store.markDeleted(id: trackId, updatedAt: now.addingTimeInterval(2))
        XCTAssertNil(try store.fetchActiveLocal(id: trackId))
        XCTAssertEqual(try store.fetch(id: trackId)?.isDeleted, true)
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

    func testPlayerQueuePersistsLibraryImportedAndPurchasedITunesTracks() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let trackStore = SQLiteTrackStore(executor: executor)
        let queueStore = SQLitePlayerQueueStore(executor: executor)
        let stateStore = SQLitePlayerStateStore(executor: executor)
        let databaseStore = PlayerDatabaseStore(
            queueStore: queueStore,
            stateStore: stateStore
        )
        let libraryTrack = makeTrack(fileName: "Library.mp3")
        var importedTrack = makeTrack(fileName: "Imported.m4a")
        importedTrack.source = .imported
        let purchasedAssetURL = try XCTUnwrap(
            URL(string: "ipod-library://item/item.m4a?id=1001")
        )
        let secondPurchasedAssetURL = try XCTUnwrap(
            URL(string: "ipod-library://item/item.m4a?id=1002")
        )
        let libraryPlayerTrack = makePlayerTrack(
            trackId: libraryTrack.id,
            title: "Library",
            source: .library,
            assetURL: nil
        )
        let importedPlayerTrack = makePlayerTrack(
            trackId: importedTrack.id,
            title: "Imported",
            source: .imported,
            assetURL: URL(string: "file:///tmp/Imported.m4a")
        )
        let purchasedPlayerTrack = makePlayerTrack(
            trackId: UUID(),
            title: "Purchased First",
            source: .purchasedITunes,
            assetURL: purchasedAssetURL
        )
        let secondPurchasedPlayerTrack = makePlayerTrack(
            trackId: UUID(),
            title: "Purchased Second",
            source: .purchasedITunes,
            assetURL: secondPurchasedAssetURL
        )

        try trackStore.insert(libraryTrack)
        try trackStore.insert(importedTrack)

        // Проверяем добавление purchased iTunes-трека в пустую очередь.
        try databaseStore.replaceQueue([purchasedPlayerTrack])
        XCTAssertEqual(try databaseStore.fetchQueue(), [purchasedPlayerTrack])

        // Проверяем добавление purchased iTunes-трека к обычному library-треку.
        try databaseStore.replaceQueue([
            libraryPlayerTrack,
            purchasedPlayerTrack
        ])
        XCTAssertEqual(
            try databaseStore.fetchQueue(),
            [libraryPlayerTrack, purchasedPlayerTrack]
        )

        // Сохраняем смешанную очередь с несколькими purchased iTunes-треками.
        let expectedQueue = [
            libraryPlayerTrack,
            importedPlayerTrack,
            purchasedPlayerTrack,
            secondPurchasedPlayerTrack
        ]
        try databaseStore.replaceQueue(expectedQueue)

        let statePersistence = PlayerStatePersistence(databaseStore: databaseStore)
        try statePersistence.saveCurrentTrack(
            trackId: purchasedPlayerTrack.trackId,
            queueItemId: purchasedPlayerTrack.queueItemId,
            duration: purchasedPlayerTrack.duration,
            playbackMode: .defaultValue
        )

        let databaseURL = try XCTUnwrap(database.databaseURL)
        try database.close()

        // Повторное открытие базы моделирует восстановление очереди после перезапуска приложения.
        let reopenedDatabase = AppDatabase(
            location: DatabaseLocation(databaseURL: databaseURL),
            migrator: DatabaseMigrator(migrations: DatabaseMigration.all)
        )
        try reopenedDatabase.open()
        self.database = reopenedDatabase

        let reopenedExecutor = try reopenedDatabase.databaseExecutor()
        let reopenedDatabaseStore = PlayerDatabaseStore(
            queueStore: SQLitePlayerQueueStore(executor: reopenedExecutor),
            stateStore: SQLitePlayerStateStore(executor: reopenedExecutor)
        )
        let restoredQueue = try reopenedDatabaseStore.fetchQueue()
        let restoredState = try XCTUnwrap(reopenedDatabaseStore.fetchState())

        XCTAssertEqual(restoredQueue, expectedQueue)
        XCTAssertEqual(restoredState.currentTrackId, purchasedPlayerTrack.trackId)
        XCTAssertEqual(
            restoredState.currentQueueItemId,
            purchasedPlayerTrack.queueItemId
        )

        let restoredPurchasedTracks = restoredQueue.filter {
            $0.source == .purchasedITunes
        }
        XCTAssertEqual(restoredPurchasedTracks.count, 2)
        XCTAssertEqual(restoredPurchasedTracks[0].assetURL, purchasedAssetURL)
        XCTAssertEqual(
            restoredPurchasedTracks[1].assetURL,
            secondPurchasedAssetURL
        )

        // Очистка очереди должна обнулить только current_queue_item_id через сохранённый внешний ключ.
        try reopenedDatabaseStore.clearQueue()
        XCTAssertTrue(try reopenedDatabaseStore.fetchQueue().isEmpty)
        let stateAfterClear = try XCTUnwrap(reopenedDatabaseStore.fetchState())
        XCTAssertNil(stateAfterClear.currentQueueItemId)
        XCTAssertEqual(
            stateAfterClear.currentTrackId,
            purchasedPlayerTrack.trackId
        )

        // Связь current_queue_item_id с player_queue остаётся обязательной.
        var invalidQueueReferenceState = stateAfterClear
        invalidQueueReferenceState.currentQueueItemId = UUID()
        XCTAssertThrowsError(
            try reopenedDatabaseStore.saveState(invalidQueueReferenceState)
        )

        let foreignKeyViolations: [String] = try reopenedExecutor.fetchAll(
            "PRAGMA foreign_key_check;",
            map: { try $0.requiredString(at: 0) }
        )
        XCTAssertTrue(foreignKeyViolations.isEmpty)
    }

    func testCanonicalLocalTrackIDFlowsThroughSearchTrackListAndPlayerQueueAfterReload() async throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let libraryStore = LibraryDatabaseStore(executor: executor)
        let trackListStore = TrackListDatabaseStore(executor: executor)
        let playerStore = PlayerDatabaseStore(
            queueStore: SQLitePlayerQueueStore(executor: executor),
            stateStore: SQLitePlayerStateStore(executor: executor)
        )
        let rootFolderId = UUID()
        let trackId = UUID()
        let trackListId = UUID()
        let listItemId = UUID()
        let queueItemId = UUID()
        let createdAt = Date(timeIntervalSince1970: 100)

        try libraryStore.upsertRootFolder(
            id: rootFolderId,
            name: "Music"
        )
        try libraryStore.upsertLibraryTrack(
            id: trackId,
            fileName: "Needle.mp3",
            relativePath: "Needle.mp3",
            folderId: rootFolderId,
            rootFolderId: rootFolderId,
            fileDate: createdAt
        )
        try libraryStore.upsertTrackMetadata(
            TrackMetadataDatabaseModel(
                trackId: trackId,
                title: "Needle",
                artist: "Artist",
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
                duration: 180,
                bitrate: nil,
                sampleRate: nil,
                channelCount: nil,
                metadataUpdatedAt: createdAt
            )
        )

        let trackListTrack = Track(
            listItemId: listItemId,
            trackId: trackId,
            title: "Needle",
            artist: "Artist",
            duration: 180,
            fileName: "Needle.mp3",
            isAvailable: true
        )
        _ = try trackListStore.createTrackList(
            id: trackListId,
            name: "List",
            kind: .regular,
            createdAt: createdAt,
            tracks: [trackListTrack]
        )

        let queueTrack = PlayerTrack(
            queueItemId: queueItemId,
            trackId: trackId,
            title: "Needle",
            artist: "Artist",
            duration: 180,
            fileName: "Needle.mp3",
            isAvailable: true
        )
        try playerStore.replaceQueue([queueTrack])

        let registry = TrackRegistry(database: database)
        let trackListsManager = TrackListsManager(databaseStore: trackListStore)
        let trackListManager = TrackListManager(databaseStore: trackListStore)
        let badgeIndex = TrackListBadgeIndex(
            trackListsManager: trackListsManager,
            trackListManager: trackListManager,
            observesTrackListChanges: false
        )
        let searchService = SearchService(
            trackRegistry: registry,
            trackListBadgeIndex: badgeIndex,
            trackListsManager: trackListsManager,
            trackListManager: trackListManager
        )

        let searchResults = try await searchService.search(query: "Needle")
        XCTAssertEqual(searchResults.tracks.map(\.id), [trackId])
        XCTAssertEqual(searchResults.tracks.map(\.trackId), [trackId])
        XCTAssertEqual(
            try trackListManager.loadTracks(for: trackListId).map(\.trackId),
            [trackId]
        )
        XCTAssertEqual(try playerStore.fetchQueue().map(\.trackId), [trackId])
        XCTAssertEqual(try playerStore.fetchQueue().map(\.queueItemId), [queueItemId])
        XCTAssertNotEqual(queueItemId, trackId)

        let databaseURL = try XCTUnwrap(database.databaseURL)
        try database.close()

        let reopenedDatabase = AppDatabase(
            location: DatabaseLocation(databaseURL: databaseURL),
            migrator: DatabaseMigrator(migrations: DatabaseMigration.all)
        )
        try reopenedDatabase.open()
        self.database = reopenedDatabase

        let reopenedExecutor = try reopenedDatabase.databaseExecutor()
        let reopenedLibraryStore = LibraryDatabaseStore(executor: reopenedExecutor)
        let reopenedTrackListStore = TrackListDatabaseStore(executor: reopenedExecutor)
        let reopenedPlayerStore = PlayerDatabaseStore(
            queueStore: SQLitePlayerQueueStore(executor: reopenedExecutor),
            stateStore: SQLitePlayerStateStore(executor: reopenedExecutor)
        )

        XCTAssertEqual(try reopenedLibraryStore.fetchTrack(id: trackId)?.id, trackId)
        XCTAssertEqual(
            try reopenedTrackListStore.fetchTracks(for: trackListId).map(\.trackId),
            [trackId]
        )
        XCTAssertEqual(try reopenedPlayerStore.fetchQueue().map(\.trackId), [trackId])
        XCTAssertEqual(
            try reopenedPlayerStore.fetchQueue().map(\.queueItemId),
            [queueItemId]
        )
    }

    func testManagedLibraryPathUpdatesKeepTrackIDAndTrackListReference() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let libraryStore = LibraryDatabaseStore(executor: executor)
        let trackListStore = TrackListDatabaseStore(executor: executor)
        let firstRootFolderId = UUID()
        let secondRootFolderId = UUID()
        let firstFolderId = UUID()
        let secondFolderId = UUID()
        let trackId = UUID()
        let trackListId = UUID()
        let createdAt = Date(timeIntervalSince1970: 200)

        try libraryStore.upsertRootFolder(id: firstRootFolderId, name: "First")
        try libraryStore.upsertRootFolder(id: secondRootFolderId, name: "Second")
        try libraryStore.upsertLibraryTrack(
            id: trackId,
            fileName: "Original.mp3",
            relativePath: "Album/Original.mp3",
            folderId: firstFolderId,
            rootFolderId: firstRootFolderId,
            fileDate: createdAt
        )
        _ = try trackListStore.createTrackList(
            id: trackListId,
            name: "List",
            kind: .regular,
            createdAt: createdAt,
            tracks: [
                Track(
                    trackId: trackId,
                    title: "Original",
                    artist: nil,
                    duration: 180,
                    fileName: "Original.mp3",
                    isAvailable: true
                )
            ]
        )

        // Переименование, выполненное приложением, передаёт прежний trackId и обновляет только файловые поля.
        try libraryStore.upsertLibraryTrack(
            id: trackId,
            fileName: "Renamed.mp3",
            relativePath: "Album/Renamed.mp3",
            folderId: firstFolderId,
            rootFolderId: firstRootFolderId,
            fileDate: createdAt
        )

        XCTAssertNil(
            try libraryStore.fetchLibraryTrack(
                rootFolderId: firstRootFolderId,
                relativePath: "Album/Original.mp3"
            )
        )
        XCTAssertEqual(
            try libraryStore.fetchLibraryTrack(
                rootFolderId: firstRootFolderId,
                relativePath: "Album/Renamed.mp3"
            )?.id,
            trackId
        )

        // Перемещение, выполненное приложением, сохраняет тот же trackId и меняет корень с относительным путём.
        try libraryStore.upsertLibraryTrack(
            id: trackId,
            fileName: "Renamed.mp3",
            relativePath: "Moved/Renamed.mp3",
            folderId: secondFolderId,
            rootFolderId: secondRootFolderId,
            fileDate: createdAt
        )

        let movedTrack = try XCTUnwrap(
            libraryStore.fetchLibraryTrack(
                rootFolderId: secondRootFolderId,
                relativePath: "Moved/Renamed.mp3"
            )
        )
        XCTAssertEqual(movedTrack.id, trackId)
        XCTAssertEqual(movedTrack.fileName, "Renamed.mp3")
        XCTAssertEqual(
            try trackListStore.fetchTracks(for: trackListId).map(\.trackId),
            [trackId]
        )
    }

    func testMetadataAndTemporaryUnavailabilityKeepCanonicalTrackIDAndReferences() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let libraryStore = LibraryDatabaseStore(executor: executor)
        let trackListStore = TrackListDatabaseStore(executor: executor)
        let playerStore = PlayerDatabaseStore(
            queueStore: SQLitePlayerQueueStore(executor: executor),
            stateStore: SQLitePlayerStateStore(executor: executor)
        )
        let rootFolderId = UUID()
        let trackId = UUID()
        let trackListId = UUID()
        let createdAt = Date(timeIntervalSince1970: 300)

        try libraryStore.upsertRootFolder(id: rootFolderId, name: "Music")
        try libraryStore.upsertLibraryTrack(
            id: trackId,
            fileName: "Track.mp3",
            relativePath: "Track.mp3",
            folderId: rootFolderId,
            rootFolderId: rootFolderId,
            fileDate: createdAt
        )
        _ = try trackListStore.createTrackList(
            id: trackListId,
            name: "List",
            kind: .regular,
            createdAt: createdAt,
            tracks: [
                Track(
                    trackId: trackId,
                    title: "Before",
                    artist: "Artist",
                    duration: 180,
                    fileName: "Track.mp3",
                    isAvailable: true
                )
            ]
        )
        try playerStore.replaceQueue([
            PlayerTrack(
                queueItemId: UUID(),
                trackId: trackId,
                title: "Before",
                artist: "Artist",
                duration: 180,
                fileName: "Track.mp3",
                isAvailable: true
            )
        ])

        try libraryStore.upsertTrackMetadata(
            TrackMetadataDatabaseModel(
                trackId: trackId,
                title: "After",
                artist: "Another Artist",
                album: "Album",
                albumArtist: nil,
                label: nil,
                genre: "Genre",
                year: 2026,
                trackNumber: nil,
                discNumber: nil,
                bpm: nil,
                keySignature: nil,
                comment: "Comment",
                duration: 181,
                bitrate: nil,
                sampleRate: nil,
                channelCount: nil,
                metadataUpdatedAt: createdAt.addingTimeInterval(1)
            )
        )
        try libraryStore.updateTrackAvailability(id: trackId, isAvailable: false)

        XCTAssertEqual(try libraryStore.fetchTrack(id: trackId)?.id, trackId)
        XCTAssertFalse(try libraryStore.fetchTrack(id: trackId)?.isAvailable ?? true)
        XCTAssertEqual(try libraryStore.fetchTrackMetadata(trackId: trackId)?.title, "After")
        XCTAssertEqual(
            try trackListStore.fetchTracks(for: trackListId).map(\.trackId),
            [trackId]
        )
        XCTAssertEqual(try playerStore.fetchQueue().map(\.trackId), [trackId])
    }

    func testDifferentFilesWithMatchingMetadataKeepDifferentCanonicalTrackIDs() throws {
        let database = try makeDatabase()
        let store = try LibraryDatabaseStore(database: database)
        let rootFolderId = UUID()
        let firstTrackId = UUID()
        let secondTrackId = UUID()
        let createdAt = Date(timeIntervalSince1970: 400)

        try store.upsertRootFolder(id: rootFolderId, name: "Music")
        try store.upsertLibraryTrack(
            id: firstTrackId,
            fileName: "First.mp3",
            relativePath: "First.mp3",
            folderId: rootFolderId,
            rootFolderId: rootFolderId,
            fileDate: createdAt
        )
        try store.upsertLibraryTrack(
            id: secondTrackId,
            fileName: "Second.mp3",
            relativePath: "Second.mp3",
            folderId: rootFolderId,
            rootFolderId: rootFolderId,
            fileDate: createdAt
        )

        for trackId in [firstTrackId, secondTrackId] {
            try store.upsertTrackMetadata(
                TrackMetadataDatabaseModel(
                    trackId: trackId,
                    title: "Same Title",
                    artist: "Same Artist",
                    album: "Same Album",
                    albumArtist: nil,
                    label: nil,
                    genre: nil,
                    year: nil,
                    trackNumber: nil,
                    discNumber: nil,
                    bpm: nil,
                    keySignature: nil,
                    comment: nil,
                    duration: 180,
                    bitrate: nil,
                    sampleRate: nil,
                    channelCount: nil,
                    metadataUpdatedAt: createdAt
                )
            )
        }

        XCTAssertNotEqual(firstTrackId, secondTrackId)
        XCTAssertEqual(try store.fetchTrackMetadata(trackId: firstTrackId)?.title, "Same Title")
        XCTAssertEqual(try store.fetchTrackMetadata(trackId: secondTrackId)?.title, "Same Title")
    }

    func testPurchasedITunesTrackUsesPersistentMediaIdentityAndKeepsItInTrackListSnapshot() throws {
        let database = try makeDatabase()
        let store = TrackListDatabaseStore(executor: try database.databaseExecutor())
        let assetURL = try XCTUnwrap(URL(string: "ipod-library://item/item.m4a?id=1001"))
        let sourceTrack = PurchasedITunesTrack(
            id: 1001,
            title: "Purchased",
            artist: "Artist",
            album: "Album",
            year: 2026,
            genre: "Genre",
            dateAdded: Date(timeIntervalSince1970: 500),
            artworkData: nil,
            duration: 180,
            assetURL: assetURL
        )

        let firstAdapter = PurchasedITunesPlayableTrack(track: sourceTrack)
        let restoredAdapter = PurchasedITunesPlayableTrack(track: sourceTrack)
        let copiedLocalTrackId = UUID()
        let trackList = try store.createTrackList(
            id: UUID(),
            name: "List",
            kind: .regular,
            createdAt: Date(timeIntervalSince1970: 500),
            tracks: [Track(purchasedITunesTrack: firstAdapter)]
        )

        XCTAssertEqual(firstAdapter.trackId, restoredAdapter.trackId)
        XCTAssertEqual(firstAdapter.id, firstAdapter.trackId)
        XCTAssertNotEqual(firstAdapter.trackId, copiedLocalTrackId)
        XCTAssertEqual(try store.fetchTracks(for: trackList.id).map(\.trackId), [firstAdapter.trackId])
        XCTAssertEqual(try store.fetchTracks(for: trackList.id).map(\.source), [.purchasedITunes])
        XCTAssertEqual(try store.fetchTracks(for: trackList.id).first?.assetURL, assetURL)
    }

    func testPlayerStatePersistenceUpsertsSinglePausedRow() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let trackStore = SQLiteTrackStore(executor: executor)
        let trackId = UUID()
        let firstDate = Date(timeIntervalSince1970: 100)

        try trackStore.insert(
            TrackDatabaseModel(
                id: trackId,
                source: .library,
                folderId: nil,
                rootFolderId: nil,
                fileName: "State.mp3",
                relativePath: "State.mp3",
                fileExtension: "mp3",
                fileSize: nil,
                fileDate: firstDate,
                importedAt: firstDate,
                updatedAt: firstDate,
                bookmarkBase64: nil,
                assetURLString: nil,
                isAvailable: true,
                isDeleted: false
            )
        )

        let databaseStore = PlayerDatabaseStore(
            queueStore: SQLitePlayerQueueStore(executor: executor),
            stateStore: SQLitePlayerStateStore(executor: executor)
        )
        let persistence = PlayerStatePersistence(databaseStore: databaseStore)

        try persistence.saveCurrentTrack(
            trackId: trackId,
            queueItemId: nil,
            duration: 120,
            playbackMode: PlaybackMode(
                isShuffleEnabled: true,
                repeatMode: .all
            )
        )
        try persistence.saveCurrentTrack(
            trackId: trackId,
            queueItemId: nil,
            duration: 0,
            playbackMode: .defaultValue
        )

        let state = try XCTUnwrap(persistence.loadState())
        XCTAssertEqual(state.id, 1)
        XCTAssertEqual(state.currentTrackId, trackId)
        XCTAssertNil(state.currentQueueItemId)
        XCTAssertEqual(state.playbackTime, 0)
        XCTAssertNil(state.duration)
        XCTAssertFalse(state.isPlaying)
        XCTAssertEqual(state.contextType, .playerQueue)
        XCTAssertNil(state.contextId)
        XCTAssertNil(state.collectionCategory)
        XCTAssertNil(state.collectionValue)
        XCTAssertNil(state.collectionArtistKey)
        XCTAssertEqual(state.repeatMode, .off)
        XCTAssertFalse(state.shuffleEnabled)

        let ids = try executor.fetchAll(
            "SELECT id FROM player_state;",
            map: { try $0.requiredInt(at: 0) }
        )
        XCTAssertEqual(ids, [1])

        let trackListId = UUID()
        try persistence.saveCurrentTrack(
            trackId: trackId,
            queueItemId: nil,
            duration: 120,
            playbackMode: .defaultValue,
            contextSource: .trackList(id: trackListId)
        )

        let trackListState = try XCTUnwrap(persistence.loadState())
        XCTAssertEqual(trackListState.id, 1)
        XCTAssertEqual(trackListState.contextType, .trackList)
        XCTAssertEqual(trackListState.contextId, trackListId)
        XCTAssertNil(trackListState.collectionCategory)
        XCTAssertNil(trackListState.collectionValue)
        XCTAssertNil(trackListState.collectionArtistKey)

        let folderId = UUID()
        try persistence.saveCurrentTrack(
            trackId: trackId,
            queueItemId: nil,
            duration: 120,
            playbackMode: .defaultValue,
            contextSource: .libraryFolder(id: folderId)
        )

        let folderState = try XCTUnwrap(persistence.loadState())
        XCTAssertEqual(folderState.contextType, .libraryFolder)
        XCTAssertEqual(folderState.contextId, folderId)
        XCTAssertNil(folderState.collectionCategory)
        XCTAssertNil(folderState.collectionValue)
        XCTAssertNil(folderState.collectionArtistKey)

        try persistence.saveCurrentTrack(
            trackId: trackId,
            queueItemId: nil,
            duration: 120,
            playbackMode: .defaultValue,
            contextSource: .libraryRoot
        )

        let rootState = try XCTUnwrap(persistence.loadState())
        XCTAssertEqual(rootState.contextType, .libraryRoot)
        XCTAssertNil(rootState.contextId)
        XCTAssertNil(rootState.collectionCategory)
        XCTAssertNil(rootState.collectionValue)
        XCTAssertNil(rootState.collectionArtistKey)

        try persistence.saveCurrentTrack(
            trackId: trackId,
            queueItemId: nil,
            duration: 120,
            playbackMode: .defaultValue,
            contextSource: .libraryCollection(
                category: .albums,
                rawValue: "Discovery",
                artistKey: "Daft Punk"
            )
        )

        let collectionState = try XCTUnwrap(persistence.loadState())
        XCTAssertEqual(collectionState.contextType, .libraryCollection)
        XCTAssertNil(collectionState.contextId)
        XCTAssertEqual(collectionState.collectionCategory, "albums")
        XCTAssertEqual(collectionState.collectionValue, "Discovery")
        XCTAssertEqual(collectionState.collectionArtistKey, "Daft Punk")

        try persistence.clearState()
        XCTAssertNil(try persistence.loadState())
    }

    /// iTunes trackId не принадлежит tracks, но после миграции сохраняется в player_state вместе с отдельным источником.
    func testPlayerStatePersistenceStoresPurchasedITunesTrackIdAndSource() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let externalTrackId = UUID()
        let persistence = PlayerStatePersistence(
            databaseStore: PlayerDatabaseStore(
                queueStore: SQLitePlayerQueueStore(executor: executor),
                stateStore: SQLitePlayerStateStore(executor: executor)
            )
        )

        try persistence.saveCurrentTrack(
            trackId: externalTrackId,
            queueItemId: nil,
            duration: 180,
            playbackMode: .defaultValue,
            contextSource: .purchasedITunes
        )

        let state = try XCTUnwrap(persistence.loadState())
        XCTAssertEqual(state.currentTrackId, externalTrackId)
        XCTAssertEqual(state.contextType, .purchasedITunes)
        XCTAssertNil(state.currentQueueItemId)
    }

    func testSQLitePlayerStateStoreUpsertsEveryPlaybackContext() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let stateStore = SQLitePlayerStateStore(executor: executor)
        let trackId = UUID()
        let trackListId = UUID()
        let folderId = UUID()
        let now = Date(timeIntervalSince1970: 200)

        let trackStore = SQLiteTrackStore(executor: executor)
        try trackStore.insert(
            TrackDatabaseModel(
                id: trackId,
                source: .library,
                folderId: nil,
                rootFolderId: nil,
                fileName: "PlaybackContext.mp3",
                relativePath: "PlaybackContext.mp3",
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
        )

        let sources: [PlaybackContextSource] = [
            .playerQueue,
            .trackList(id: trackListId),
            .libraryFolder(id: folderId),
            .libraryRoot,
            .libraryCollection(
                category: .genres,
                rawValue: "House",
                artistKey: nil
            ),
            .purchasedITunes
        ]

        for source in sources {
            let model = PlayerStateDatabaseModel(
                id: 1,
                currentQueueItemId: nil,
                currentTrackId: trackId,
                contextType: PlaybackContextSourceDatabaseMapper.databaseType(from: source),
                contextId: PlaybackContextSourceDatabaseMapper.contextId(from: source),
                collectionCategory: PlaybackContextSourceDatabaseMapper.collectionCategory(from: source),
                collectionValue: PlaybackContextSourceDatabaseMapper.collectionValue(from: source),
                collectionArtistKey: PlaybackContextSourceDatabaseMapper.collectionArtistKey(from: source),
                playbackTime: 0,
                duration: 120,
                isPlaying: false,
                repeatMode: .off,
                shuffleEnabled: false,
                updatedAt: now
            )

            try stateStore.upsert(model)

            let restored = try XCTUnwrap(stateStore.fetch())
            XCTAssertEqual(restored.currentTrackId, trackId)
            XCTAssertEqual(restored.contextType, model.contextType)
            XCTAssertEqual(restored.contextId, model.contextId)
            XCTAssertEqual(restored.collectionCategory, model.collectionCategory)
            XCTAssertEqual(restored.collectionValue, model.collectionValue)
            XCTAssertEqual(restored.collectionArtistKey, model.collectionArtistKey)
        }

        let collectionModel = PlayerStateDatabaseModel(
            id: 1,
            currentQueueItemId: nil,
            currentTrackId: trackId,
            contextType: .libraryCollection,
            contextId: nil,
            collectionCategory: "genres",
            collectionValue: "House",
            collectionArtistKey: nil,
            playbackTime: 0,
            duration: 120,
            isPlaying: false,
            repeatMode: .off,
            shuffleEnabled: false,
            updatedAt: now
        )
        try stateStore.upsert(collectionModel)

        let folderModel = PlayerStateDatabaseModel(
            id: 1,
            currentQueueItemId: nil,
            currentTrackId: trackId,
            contextType: .libraryFolder,
            contextId: folderId,
            collectionCategory: nil,
            collectionValue: nil,
            collectionArtistKey: nil,
            playbackTime: 0,
            duration: 120,
            isPlaying: false,
            repeatMode: .off,
            shuffleEnabled: false,
            updatedAt: now.addingTimeInterval(1)
        )
        try stateStore.upsert(folderModel)

        let restoredFolder = try XCTUnwrap(stateStore.fetch())
        XCTAssertEqual(restoredFolder.contextType, .libraryFolder)
        XCTAssertEqual(restoredFolder.contextId, folderId)
        XCTAssertNil(restoredFolder.collectionCategory)
        XCTAssertNil(restoredFolder.collectionValue)
        XCTAssertNil(restoredFolder.collectionArtistKey)
    }

    func testSQLitePlayerStateStoreInsertAndUpdateKeepParameterOrder() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let trackStore = SQLiteTrackStore(executor: executor)
        let stateStore = SQLitePlayerStateStore(executor: executor)
        let track = makeTrack(fileName: "InsertUpdateState.mp3")

        try trackStore.insert(track)

        let now = Date(timeIntervalSince1970: 300)
        let initial = PlayerStateDatabaseModel(
            id: 1,
            currentQueueItemId: nil,
            currentTrackId: track.id,
            contextType: .libraryCollection,
            contextId: nil,
            collectionCategory: "genres",
            collectionValue: "House",
            collectionArtistKey: nil,
            playbackTime: 0,
            duration: 120,
            isPlaying: false,
            repeatMode: .off,
            shuffleEnabled: false,
            updatedAt: now
        )
        try stateStore.insert(initial)

        let inserted = try XCTUnwrap(stateStore.fetch())
        XCTAssertEqual(inserted.collectionCategory, "genres")
        XCTAssertEqual(inserted.collectionValue, "House")

        var updated = initial
        updated.contextType = .libraryRoot
        updated.collectionCategory = nil
        updated.collectionValue = nil
        updated.updatedAt = now.addingTimeInterval(1)
        try stateStore.update(updated)

        let restored = try XCTUnwrap(stateStore.fetch())
        XCTAssertEqual(restored.contextType, .libraryRoot)
        XCTAssertNil(restored.contextId)
        XCTAssertNil(restored.collectionCategory)
        XCTAssertNil(restored.collectionValue)
        XCTAssertNil(restored.collectionArtistKey)
    }

    func testPlayerDatabaseStorePreservesCurrentQueueReferenceWhenReplacingQueue() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let trackStore = SQLiteTrackStore(executor: executor)
        let databaseStore = PlayerDatabaseStore(
            queueStore: SQLitePlayerQueueStore(executor: executor),
            stateStore: SQLitePlayerStateStore(executor: executor)
        )
        let track = makeTrack(fileName: "QueueState.mp3")
        let queueItemId = UUID()

        try trackStore.insert(track)

        let playerTrack = PlayerTrack(
            queueItemId: queueItemId,
            trackId: track.id,
            title: "Queue state",
            artist: nil,
            duration: 30,
            fileName: track.fileName,
            isAvailable: true
        )
        try databaseStore.replaceQueue([playerTrack])

        let persistence = PlayerStatePersistence(databaseStore: databaseStore)
        try persistence.saveCurrentTrack(
            trackId: track.id,
            queueItemId: queueItemId,
            duration: playerTrack.duration,
            playbackMode: .defaultValue
        )

        // Повторная запись очереди не должна терять ссылку на оставшийся текущий элемент.
        try databaseStore.replaceQueue([playerTrack])

        XCTAssertEqual(try databaseStore.fetchState()?.currentQueueItemId, queueItemId)
    }

    func testPlayerPlaybackModePersistsStableValues() throws {
        let database = try makeDatabase()
        let store = try SQLitePlayerSettingsStore(database: database)
        let updatedAt = Date(timeIntervalSince1970: 100)

        // Проверяем, что режим хранится в player_settings, а не во временном runtime-состоянии.
        try store.upsertPlaybackMode(
            PlayerPlaybackModeDatabaseModel(
                repeatMode: .all,
                shuffleEnabled: false,
                updatedAt: updatedAt
            )
        )

        let loaded = try XCTUnwrap(store.fetchPlaybackMode())
        XCTAssertEqual(loaded.repeatMode, .all)
        XCTAssertFalse(loaded.shuffleEnabled)
        XCTAssertEqual(loaded.updatedAt, updatedAt)

        try store.upsertPlaybackMode(
            PlayerPlaybackModeDatabaseModel(
                repeatMode: .off,
                shuffleEnabled: true,
                updatedAt: updatedAt.addingTimeInterval(1)
            )
        )

        let updated = try XCTUnwrap(store.fetchPlaybackMode())
        XCTAssertEqual(updated.repeatMode, .off)
        XCTAssertTrue(updated.shuffleEnabled)
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

    func testTrackListStorePersistsRegularAndFavoritesKinds() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = SQLiteTrackListStore(executor: executor)
        let createdAt = Date(timeIntervalSince1970: 100)
        let regular = TrackListDatabaseModel(
            id: UUID(),
            name: "Regular",
            kind: .regular,
            createdAt: createdAt,
            updatedAt: createdAt,
            sortOrder: 0,
            isDeleted: false
        )
        let favorites = TrackListDatabaseModel(
            id: UUID(),
            name: "Favorites",
            kind: .favorites,
            createdAt: createdAt,
            updatedAt: createdAt,
            sortOrder: 1,
            isDeleted: false
        )

        try store.insert(regular)
        try store.insert(favorites)

        XCTAssertEqual(try store.fetch(id: regular.id)?.kind, .regular)
        XCTAssertEqual(try store.fetch(id: favorites.id)?.kind, .favorites)

        var updatedFavorites = favorites
        updatedFavorites.name = "Renamed Favorites"
        updatedFavorites.updatedAt = createdAt.addingTimeInterval(1)
        try store.update(updatedFavorites)

        XCTAssertEqual(try store.fetch(id: favorites.id)?.kind, .favorites)
    }

    @MainActor
    func testFavoritesManagementCapabilitiesAreHiddenInPresentationState() {
        let favorites = TrackList(
            id: UUID(),
            name: "Любое название",
            createdAt: Date(timeIntervalSince1970: 100),
            kind: .favorites,
            tracks: []
        )
        let regular = TrackList(
            id: UUID(),
            name: "Избранное",
            createdAt: Date(timeIntervalSince1970: 200),
            kind: .regular,
            tracks: []
        )

        XCTAssertFalse(favorites.kind.canRename)
        XCTAssertFalse(favorites.kind.canDelete)
        XCTAssertFalse(favorites.kind.canReorder)
        XCTAssertTrue(regular.kind.canRename)
        XCTAssertTrue(regular.kind.canDelete)
        XCTAssertTrue(regular.kind.canReorder)

        let listState = TrackListsScreenStateBuilder().build(
            trackLists: [favorites, regular],
            selectedSortMode: nil
        )
        XCTAssertFalse(listState.rows[0].canDelete)
        XCTAssertFalse(listState.rows[0].canReorder)
        XCTAssertEqual(
            listState.rows[0].title,
            TrackListPresentationText.title(
                for: favorites.kind,
                storedName: favorites.name
            )
        )
        XCTAssertNotEqual(listState.rows[0].title, favorites.name)
        XCTAssertNil(listState.rows[0].createdAtText)
        XCTAssertTrue(listState.rows[1].canDelete)
        XCTAssertTrue(listState.rows[1].canReorder)
        XCTAssertEqual(listState.rows[1].title, regular.name)
        XCTAssertEqual(
            listState.rows[1].createdAtText,
            TrackListPresentationText.createdAt(regular.createdAt)
        )

        let detailState = TrackListScreenStateBuilder().build(
            id: favorites.id,
            title: favorites.name,
            kind: favorites.kind,
            canRenameTrackList: favorites.kind.canRename,
            summary: nil,
            tracks: [],
            snapshotsByTrackId: [:],
            currentTrackId: nil,
            currentContext: nil,
            isPlaying: false,
            highlightedRowId: nil,
            favoriteTrackIds: [],
            settings: AppSettings.defaultValue,
            collectionNavigationTargetsByTrackId: [:]
        )
        XCTAssertEqual(
            detailState.title,
            TrackListPresentationText.title(
                for: favorites.kind,
                storedName: favorites.name
            )
        )
        XCTAssertFalse(detailState.canRenameTrackList)
    }

    func testTrackListDatabaseStorePreservesFavoritesKindDuringMetadataUpdates() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let databaseStore = TrackListDatabaseStore(executor: executor)
        let trackListStore = SQLiteTrackListStore(executor: executor)
        let trackListId = UUID()
        let createdAt = Date(timeIntervalSince1970: 100)
        let favorites = TrackListDatabaseModel(
            id: trackListId,
            name: "Favorites",
            kind: .favorites,
            createdAt: createdAt,
            updatedAt: createdAt,
            sortOrder: 0,
            isDeleted: false
        )

        // Системный треклист создаётся напрямую только для проверки persistence-слоя.
        try trackListStore.insert(favorites)

        try databaseStore.renameTrackList(id: trackListId, to: "Renamed Favorites")
        XCTAssertEqual(try trackListStore.fetch(id: trackListId)?.kind, .favorites)

        try databaseStore.updateTrackListsOrder([])
        XCTAssertEqual(try trackListStore.fetch(id: trackListId)?.kind, .favorites)

        try trackListStore.markDeleted(
            id: trackListId,
            updatedAt: createdAt.addingTimeInterval(1)
        )
        XCTAssertEqual(try trackListStore.fetch(id: trackListId)?.kind, .favorites)

        try databaseStore.saveMeta(
            TrackListMeta(
                id: trackListId,
                name: "Renamed Favorites",
                createdAt: createdAt,
                kind: .favorites
            )
        )

        let restored = try XCTUnwrap(trackListStore.fetch(id: trackListId))
        XCTAssertFalse(restored.isDeleted)
        XCTAssertEqual(restored.kind, .favorites)
    }

    @MainActor
    func testTrackListsManagerRejectsFavoritesRenameAndDeletionWithoutChangingTracks() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let manager = TrackListsManager(databaseStore: store)
        let favorites = try manager.ensureFavoritesTrackList()
        let track = makeTrackListTrack(
            listItemId: UUID(),
            trackId: UUID(),
            title: "Favorite track"
        )
        try store.replaceTracks([track], for: favorites.id)

        XCTAssertThrowsError(
            try manager.renameTrackList(id: favorites.id, to: "Новое название")
        ) { error in
            guard let appError = error as? AppError,
                  case .trackListRenameNotAllowed = appError
            else {
                return XCTFail("Ожидалась ошибка запрета переименования системного треклиста")
            }
        }
        XCTAssertThrowsError(
            try manager.deleteTrackList(id: favorites.id)
        ) { error in
            guard let appError = error as? AppError,
                  case .trackListDeletionNotAllowed = appError
            else {
                return XCTFail("Ожидалась ошибка запрета удаления системного треклиста")
            }
        }

        let unchanged = try store.fetchTrackList(id: favorites.id)
        XCTAssertEqual(unchanged.name, favorites.name)
        XCTAssertEqual(unchanged.kind, .favorites)
        XCTAssertEqual(unchanged.tracks.map(\.id), [track.id])
    }

    @MainActor
    func testTrackListsManagerAllowsRegularTrackListNamedFavoritesToBeRenamedAndDeleted() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let manager = TrackListsManager(databaseStore: store)
        let regular = try store.createTrackList(
            id: UUID(),
            name: "Избранное",
            kind: .regular,
            createdAt: Date(timeIntervalSince1970: 100),
            tracks: []
        )

        try manager.renameTrackList(id: regular.id, to: "Пользовательский")
        XCTAssertEqual(try store.fetchTrackList(id: regular.id).name, "Пользовательский")

        try manager.deleteTrackList(id: regular.id)
        XCTAssertFalse(try store.exists(id: regular.id))
    }

    @MainActor
    func testTrackListsManagerProtectsFavoritesWithDifferentDisplayName() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let manager = TrackListsManager(databaseStore: store)
        let favorites = try manager.ensureFavoritesTrackList()

        // Имитируем историческое отображаемое название без изменения назначения записи.
        try store.renameTrackList(id: favorites.id, to: "Custom favorites")

        XCTAssertThrowsError(
            try manager.renameTrackList(id: favorites.id, to: "Ещё одно название")
        ) { error in
            guard let appError = error as? AppError,
                  case .trackListRenameNotAllowed = appError
            else {
                return XCTFail("Системный треклист должен определяться по kind, а не по названию")
            }
        }
        XCTAssertThrowsError(
            try manager.deleteTrackList(id: favorites.id)
        ) { error in
            guard let appError = error as? AppError,
                  case .trackListDeletionNotAllowed = appError
            else {
                return XCTFail("Системный треклист должен определяться по kind, а не по названию")
            }
        }

        XCTAssertEqual(try store.fetchTrackList(id: favorites.id).name, "Custom favorites")
        XCTAssertEqual(try store.fetchTrackList(id: favorites.id).kind, .favorites)
    }

    @MainActor
    func testTrackListDatabaseStoreProtectsFavoritesMetadataDuringFullSavesAndAllowsTrackChanges() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let manager = TrackListsManager(databaseStore: store)
        let favorites = try manager.ensureFavoritesTrackList()
        let originalTrack = makeTrackListTrack(
            listItemId: UUID(),
            trackId: UUID(),
            title: "Original"
        )
        let replacementTrack = makeTrackListTrack(
            listItemId: UUID(),
            trackId: UUID(),
            title: "Replacement"
        )
        try store.replaceTracks([originalTrack], for: favorites.id)

        XCTAssertThrowsError(
            try store.saveMeta(
                TrackListMeta(
                    id: favorites.id,
                    name: "Переименованное избранное",
                    createdAt: favorites.createdAt,
                    kind: .favorites
                )
            )
        )
        XCTAssertThrowsError(
            try store.replaceTrackLists([
                TrackList(
                    id: favorites.id,
                    name: favorites.name,
                    createdAt: favorites.createdAt,
                    kind: .regular,
                    tracks: [replacementTrack]
                )
            ])
        )

        let unchanged = try store.fetchTrackList(id: favorites.id)
        XCTAssertEqual(unchanged.name, favorites.name)
        XCTAssertEqual(unchanged.kind, .favorites)
        XCTAssertEqual(unchanged.tracks.map(\.id), [originalTrack.id])

        try store.replaceTrackLists([
            TrackList(
                id: favorites.id,
                name: favorites.name,
                createdAt: favorites.createdAt,
                kind: .favorites,
                tracks: [replacementTrack]
            )
        ])

        let updated = try store.fetchTrackList(id: favorites.id)
        XCTAssertEqual(updated.name, favorites.name)
        XCTAssertEqual(updated.kind, .favorites)
        XCTAssertEqual(updated.tracks.map(\.id), [replacementTrack.id])

        let regular = try store.createTrackList(
            id: UUID(),
            name: "Regular",
            kind: .regular,
            createdAt: Date(timeIntervalSince1970: 200),
            tracks: []
        )
        XCTAssertThrowsError(
            try store.saveMeta(
                TrackListMeta(
                    id: regular.id,
                    name: regular.name,
                    createdAt: regular.createdAt,
                    kind: .favorites
                )
            )
        )
        XCTAssertEqual(try store.fetchTrackList(id: regular.id).kind, .regular)

        try store.replaceTrackLists([regular])
        let preservedFavorites = try store.fetchTrackList(id: favorites.id)
        XCTAssertEqual(preservedFavorites.kind, .favorites)
        XCTAssertEqual(preservedFavorites.tracks.map(\.id), [replacementTrack.id])
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

    @MainActor
    func testTrackListsManagerCreatesFavoritesOnceAndKeepsUUIDAfterRecreation() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let manager = TrackListsManager(databaseStore: store)

        XCTAssertNil(try manager.favoritesTrackList())

        let first = try manager.ensureFavoritesTrackList()
        let second = try manager.ensureFavoritesTrackList()
        let recreatedManager = TrackListsManager(
            databaseStore: TrackListDatabaseStore(executor: executor)
        )
        let afterRecreation = try recreatedManager.ensureFavoritesTrackList()
        let favorites = try store.fetchMetas().filter { $0.kind == .favorites }

        XCTAssertEqual(first.kind, .favorites)
        XCTAssertEqual(first.name, "Избранное")
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.id, afterRecreation.id)
        XCTAssertEqual(favorites.map(\.id), [first.id])
        XCTAssertEqual(try recreatedManager.favoritesTrackList()?.id, first.id)
    }

    @MainActor
    func testTrackListsManagerCreatesFavoritesSeparatelyFromRegularWithSameName() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let regular = try store.createTrackList(
            id: UUID(),
            name: "Избранное",
            kind: .regular,
            createdAt: Date(timeIntervalSince1970: 100),
            tracks: []
        )
        let manager = TrackListsManager(databaseStore: store)

        let favorites = try manager.ensureFavoritesTrackList()
        let metas = try store.fetchMetas()

        XCTAssertEqual(regular.kind, .regular)
        XCTAssertEqual(metas.first { $0.id == regular.id }?.kind, .regular)
        XCTAssertEqual(favorites.kind, .favorites)
        XCTAssertNotEqual(favorites.id, regular.id)
        XCTAssertEqual(metas.filter { $0.kind == .favorites }.count, 1)
    }

    @MainActor
    func testTrackListsManagerRestoresSoftDeletedFavoritesWithSameUUID() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let databaseStore = TrackListDatabaseStore(executor: executor)
        let trackListStore = SQLiteTrackListStore(executor: executor)
        let manager = TrackListsManager(databaseStore: databaseStore)
        let favorites = try manager.ensureFavoritesTrackList()

        try trackListStore.markDeleted(id: favorites.id, updatedAt: Date())
        XCTAssertNil(try manager.favoritesTrackList())

        let restored = try manager.ensureFavoritesTrackList()
        let restoredModel = try XCTUnwrap(trackListStore.fetch(id: favorites.id))

        XCTAssertEqual(restored.id, favorites.id)
        XCTAssertFalse(restoredModel.isDeleted)
        XCTAssertEqual(restoredModel.kind, .favorites)
    }

    @MainActor
    func testTrackListsManagerDeterministicallySoftDeletesDuplicateFavorites() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let trackListStore = SQLiteTrackListStore(executor: executor)
        let primaryID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let duplicateID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let primaryDate = Date(timeIntervalSince1970: 100)
        let duplicateDate = Date(timeIntervalSince1970: 200)

        // Имитируем повреждённое историческое состояние, которое невозможно после применения индекса.
        try executor.write { database in
            try database.executeScript("DROP INDEX IF EXISTS idx_tracklists_one_active_favorites;")
        }
        try trackListStore.insert(
            makeTrackListDatabaseModel(
                id: primaryID,
                name: "Первичная запись",
                kind: .favorites,
                createdAt: primaryDate,
                isDeleted: false
            )
        )
        try trackListStore.insert(
            makeTrackListDatabaseModel(
                id: duplicateID,
                name: "Дублирующая запись",
                kind: .favorites,
                createdAt: duplicateDate,
                isDeleted: false
            )
        )

        let manager = TrackListsManager(
            databaseStore: TrackListDatabaseStore(executor: executor)
        )
        let resolved = try manager.ensureFavoritesTrackList()

        XCTAssertEqual(resolved.id, primaryID)
        XCTAssertFalse(try XCTUnwrap(trackListStore.fetch(id: primaryID)).isDeleted)
        XCTAssertTrue(try XCTUnwrap(trackListStore.fetch(id: duplicateID)).isDeleted)
    }

    func testTrackListFavoritesUniqueIndexBlocksSecondActiveRecordAndAllowsRegularRecords() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = SQLiteTrackListStore(executor: executor)
        let createdAt = Date(timeIntervalSince1970: 100)
        let firstFavorites = makeTrackListDatabaseModel(
            id: UUID(),
            name: "First favorites",
            kind: .favorites,
            createdAt: createdAt,
            isDeleted: false
        )
        let secondFavorites = makeTrackListDatabaseModel(
            id: UUID(),
            name: "Second favorites",
            kind: .favorites,
            createdAt: createdAt.addingTimeInterval(1),
            isDeleted: false
        )

        try store.insert(firstFavorites)
        XCTAssertThrowsError(try store.insert(secondFavorites))

        try store.markDeleted(id: firstFavorites.id, updatedAt: Date())
        try store.insert(secondFavorites)
        try store.insert(
            makeTrackListDatabaseModel(
                id: UUID(),
                name: "Regular one",
                kind: .regular,
                createdAt: createdAt,
                isDeleted: false
            )
        )
        try store.insert(
            makeTrackListDatabaseModel(
                id: UUID(),
                name: "Regular two",
                kind: .regular,
                createdAt: createdAt.addingTimeInterval(1),
                isDeleted: false
            )
        )

        XCTAssertTrue(try XCTUnwrap(store.fetch(id: firstFavorites.id)).isDeleted)
        XCTAssertFalse(try XCTUnwrap(store.fetch(id: secondFavorites.id)).isDeleted)
        XCTAssertEqual(try store.fetchAll().filter { $0.kind == .regular }.count, 2)
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

    @MainActor
    func testTrackListsViewModelEnsuresFavoritesBeforePublishingList() throws {
        let favorites = TrackListMeta(
            id: UUID(),
            name: "Избранное",
            createdAt: Date(timeIntervalSince1970: 100),
            kind: .favorites
        )
        let trackListsManager = TrackListsLoadingOrderSpy(metas: [favorites])
        let viewModel = TrackListsViewModel(
            loader: TrackListsLoader(
                trackListsManager: trackListsManager,
                trackListManager: TrackListLoadingOrderSpy()
            ),
            initialSortMode: nil,
            loadFailurePresenter: TrackListsToastPresenterSpy(),
            eventProvider: TrackListsEventProviderSpy(),
            navigationPruning: TrackListsNavigationPruningSpy()
        )

        viewModel.loadTrackListsIfNeeded()

        XCTAssertEqual(trackListsManager.calls, [.ensureFavorites, .loadMetas])
        XCTAssertEqual(viewModel.trackLists.map(\.id), [favorites.id])
        XCTAssertEqual(viewModel.trackLists.first?.kind, .favorites)
    }

    @MainActor
    func testTrackListsViewModelPinsFavoritesBeforePersistedRegularOrder() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let trackListStore = SQLiteTrackListStore(executor: executor)
        let regularA = TrackListMeta(
            id: UUID(),
            name: "B",
            createdAt: Date(timeIntervalSince1970: 100),
            kind: .regular
        )
        let regularB = TrackListMeta(
            id: UUID(),
            name: "A",
            createdAt: Date(timeIntervalSince1970: 200),
            kind: .regular
        )
        let favorites = TrackListMeta(
            id: UUID(),
            name: "Любое отображаемое название",
            createdAt: Date(timeIntervalSince1970: 300),
            kind: .favorites
        )

        try trackListStore.insert(
            TrackListDatabaseModel(
                id: regularA.id,
                name: regularA.name,
                kind: .regular,
                createdAt: regularA.createdAt,
                updatedAt: regularA.createdAt,
                sortOrder: 0,
                isDeleted: false
            )
        )
        try trackListStore.insert(
            TrackListDatabaseModel(
                id: regularB.id,
                name: regularB.name,
                kind: .regular,
                createdAt: regularB.createdAt,
                updatedAt: regularB.createdAt,
                sortOrder: 1,
                isDeleted: false
            )
        )
        try trackListStore.insert(
            TrackListDatabaseModel(
                id: favorites.id,
                name: favorites.name,
                kind: .favorites,
                createdAt: favorites.createdAt,
                updatedAt: favorites.createdAt,
                sortOrder: 100,
                isDeleted: false
            )
        )

        let trackListsManager = TrackListsLoadingOrderSpy(
            metas: try store.fetchMetas()
        )
        let viewModel = TrackListsViewModel(
            loader: TrackListsLoader(
                trackListsManager: trackListsManager,
                trackListManager: TrackListLoadingOrderSpy()
            ),
            initialSortMode: nil,
            loadFailurePresenter: TrackListsToastPresenterSpy(),
            eventProvider: TrackListsEventProviderSpy(),
            navigationPruning: TrackListsNavigationPruningSpy()
        )

        viewModel.loadTrackListsIfNeeded()

        XCTAssertEqual(
            viewModel.trackLists.map(\.id),
            [favorites.id, regularA.id, regularB.id]
        )
        XCTAssertEqual(viewModel.trackLists.dropFirst().map(\.name), ["B", "A"])
    }

    @MainActor
    func testTrackListsManagerRejectsOrdersThatMoveOrOmitFavorites() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let trackListStore = SQLiteTrackListStore(executor: executor)
        let manager = TrackListsManager(databaseStore: store)
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
        let favorites = try manager.ensureFavoritesTrackList()
        try manager.updateTrackListsOrder([favorites.id, regularA.id, regularB.id])
        let initialOrders = [
            try trackListStore.fetch(id: favorites.id)?.sortOrder,
            try trackListStore.fetch(id: regularA.id)?.sortOrder,
            try trackListStore.fetch(id: regularB.id)?.sortOrder
        ]

        XCTAssertThrowsError(
            try manager.updateTrackListsOrder([regularA.id, favorites.id, regularB.id])
        ) { error in
            guard let appError = error as? AppError,
                  case .trackListReorderNotAllowed = appError
            else {
                return XCTFail("Ожидалась ошибка запрета перемещения системного треклиста")
            }
        }
        XCTAssertThrowsError(
            try manager.updateTrackListsOrder([favorites.id, regularA.id, regularA.id])
        ) { error in
            guard let appError = error as? AppError,
                  case .trackListReorderNotAllowed = appError
            else {
                return XCTFail("Ожидалась ошибка некорректного пользовательского порядка")
            }
        }
        XCTAssertThrowsError(
            try manager.updateTrackListsOrder([favorites.id, regularA.id, UUID()])
        ) { error in
            guard let appError = error as? AppError,
                  case .trackListNotFound = appError
            else {
                return XCTFail("Ожидалась ошибка неизвестного треклиста")
            }
        }

        XCTAssertEqual(
            [
                try trackListStore.fetch(id: favorites.id)?.sortOrder,
                try trackListStore.fetch(id: regularA.id)?.sortOrder,
                try trackListStore.fetch(id: regularB.id)?.sortOrder
            ],
            initialOrders
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

    func testNewRegularTrackListShiftsOnlyRegularSortOrders() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let trackListStore = SQLiteTrackListStore(executor: executor)
        let first = try store.createTrackList(
            id: UUID(),
            name: "First",
            kind: .regular,
            createdAt: Date(timeIntervalSince1970: 100),
            tracks: []
        )
        let second = try store.createTrackList(
            id: UUID(),
            name: "Second",
            kind: .regular,
            createdAt: Date(timeIntervalSince1970: 200),
            tracks: []
        )
        try store.updateTrackListsOrder([first.id, second.id])
        let favorites = try store.createTrackList(
            id: UUID(),
            name: "System",
            kind: .favorites,
            createdAt: Date(timeIntervalSince1970: 300),
            tracks: []
        )
        var favoritesModel = try XCTUnwrap(trackListStore.fetch(id: favorites.id))
        favoritesModel.sortOrder = 100
        try trackListStore.upsert(favoritesModel)

        let created = try store.createTrackList(
            id: UUID(),
            name: "Created",
            kind: .regular,
            createdAt: Date(timeIntervalSince1970: 400),
            tracks: []
        )

        XCTAssertEqual(try trackListStore.fetch(id: created.id)?.sortOrder, 0)
        XCTAssertEqual(try trackListStore.fetch(id: first.id)?.sortOrder, 1)
        XCTAssertEqual(try trackListStore.fetch(id: second.id)?.sortOrder, 2)
        XCTAssertEqual(try trackListStore.fetch(id: favorites.id)?.sortOrder, 100)
    }

    @MainActor
    func testTrackListsManagerSavesRegularOrderAcrossReloadWithoutChangingFavoritesSortOrder() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let trackListStore = SQLiteTrackListStore(executor: executor)
        let manager = TrackListsManager(databaseStore: store)
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
        let regularC = try store.createTrackList(
            id: UUID(),
            name: "C",
            kind: .regular,
            createdAt: Date(timeIntervalSince1970: 300),
            tracks: []
        )
        let favorites = try manager.ensureFavoritesTrackList()
        var favoritesModel = try XCTUnwrap(trackListStore.fetch(id: favorites.id))
        favoritesModel.sortOrder = 100
        try trackListStore.upsert(favoritesModel)

        try manager.updateTrackListsOrder([
            favorites.id,
            regularC.id,
            regularA.id,
            regularB.id
        ])

        XCTAssertEqual(try trackListStore.fetch(id: regularC.id)?.sortOrder, 0)
        XCTAssertEqual(try trackListStore.fetch(id: regularA.id)?.sortOrder, 1)
        XCTAssertEqual(try trackListStore.fetch(id: regularB.id)?.sortOrder, 2)
        XCTAssertEqual(try trackListStore.fetch(id: favorites.id)?.sortOrder, 100)

        let reloadedManager = TrackListsManager(
            databaseStore: TrackListDatabaseStore(executor: executor)
        )
        let reloadedMetas = try reloadedManager.loadTrackListMetas()
        XCTAssertEqual(
            reloadedMetas.map(\.id),
            [regularC.id, regularA.id, regularB.id, favorites.id]
        )

        let viewModel = TrackListsViewModel(
            loader: TrackListsLoader(
                trackListsManager: TrackListsLoadingOrderSpy(metas: reloadedMetas),
                trackListManager: TrackListLoadingOrderSpy()
            ),
            initialSortMode: nil,
            loadFailurePresenter: TrackListsToastPresenterSpy(),
            eventProvider: TrackListsEventProviderSpy(),
            navigationPruning: TrackListsNavigationPruningSpy()
        )
        viewModel.loadTrackListsIfNeeded()

        XCTAssertEqual(
            viewModel.trackLists.map(\.id),
            [favorites.id, regularC.id, regularA.id, regularB.id]
        )
    }

    func testTrackListDatabaseStorePersistsBusinessModels() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let trackId = UUID()
        let createdAt = Date()
        let firstEntry = makeTrackListTrack(
            listItemId: UUID(),
            trackId: trackId,
            title: "First"
        )
        let secondEntry = makeTrackListTrack(
            listItemId: UUID(),
            trackId: trackId,
            title: "Second"
        )

        let created = try store.createTrackList(
            id: UUID(),
            name: "Duplicates",
            kind: .regular,
            createdAt: createdAt,
            tracks: [firstEntry, secondEntry]
        )

        XCTAssertEqual(try store.fetchMetas().map(\.id), [created.id])
        XCTAssertEqual(created.kind, .regular)
        XCTAssertEqual(try store.fetchMetas().first?.kind, .regular)
        XCTAssertEqual(try store.fetchTracks(for: created.id).map(\.id), [firstEntry.id, secondEntry.id])
        XCTAssertEqual(try store.fetchTracks(for: created.id).map(\.trackId), [trackId, trackId])

        try store.replaceTracks([secondEntry], for: created.id)

        let remainingTracks = try store.fetchTrackList(id: created.id).tracks
        XCTAssertEqual(remainingTracks.map(\.id), [secondEntry.id])
        XCTAssertEqual(remainingTracks.first?.trackId, trackId)

        try store.renameTrackList(id: created.id, to: "Renamed")
        XCTAssertEqual(try store.fetchTrackList(id: created.id).name, "Renamed")
        XCTAssertEqual(try store.fetchTrackList(id: created.id).kind, .regular)

        try store.deleteTrackList(id: created.id)
        XCTAssertFalse(try store.exists(id: created.id))
    }

    func testTrackListDatabaseStorePersistsManualTrackListOrder() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let trackListStore = SQLiteTrackListStore(executor: executor)
        let firstDate = Date(timeIntervalSince1970: 100)
        let secondDate = Date(timeIntervalSince1970: 200)
        let thirdDate = Date(timeIntervalSince1970: 300)
        let fourthDate = Date(timeIntervalSince1970: 400)

        let first = try store.createTrackList(
            id: UUID(),
            name: "First",
            kind: .regular,
            createdAt: firstDate,
            tracks: []
        )
        let second = try store.createTrackList(
            id: UUID(),
            name: "Second",
            kind: .regular,
            createdAt: secondDate,
            tracks: []
        )
        let third = try store.createTrackList(
            id: UUID(),
            name: "Third",
            kind: .regular,
            createdAt: thirdDate,
            tracks: []
        )

        XCTAssertEqual(try store.fetchMetas().map(\.id), [third.id, second.id, first.id])

        try store.updateTrackListsOrder([first.id, third.id, second.id])

        XCTAssertEqual(try store.fetchMetas().map(\.id), [first.id, third.id, second.id])
        XCTAssertEqual(try trackListStore.fetch(id: first.id)?.sortOrder, 0)
        XCTAssertEqual(try trackListStore.fetch(id: third.id)?.sortOrder, 1)
        XCTAssertEqual(try trackListStore.fetch(id: second.id)?.sortOrder, 2)

        let fourth = try store.createTrackList(
            id: UUID(),
            name: "Fourth",
            kind: .regular,
            createdAt: fourthDate,
            tracks: []
        )

        XCTAssertEqual(try store.fetchMetas().map(\.id), [fourth.id, first.id, third.id, second.id])
        XCTAssertEqual(try trackListStore.fetch(id: fourth.id)?.sortOrder, 0)
        XCTAssertEqual(try trackListStore.fetch(id: first.id)?.sortOrder, 1)
        XCTAssertEqual(try trackListStore.fetch(id: third.id)?.sortOrder, 2)
        XCTAssertEqual(try trackListStore.fetch(id: second.id)?.sortOrder, 3)
    }

    func testCreateTrackListNormalizesNilSortOrder() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let trackListStore = SQLiteTrackListStore(executor: executor)
        let olderId = UUID()
        let newerId = UUID()
        let olderDate = Date(timeIntervalSince1970: 100)
        let newerDate = Date(timeIntervalSince1970: 200)
        let createdDate = Date(timeIntervalSince1970: 300)

        // Старые записи могут не иметь sort_order, поэтому новый треклист нормализует их текущий fetchAll-порядок.
        try trackListStore.upsert(
            TrackListDatabaseModel(
                id: olderId,
                name: "Older",
                kind: .regular,
                createdAt: olderDate,
                updatedAt: olderDate,
                sortOrder: nil,
                isDeleted: false
            )
        )
        try trackListStore.upsert(
            TrackListDatabaseModel(
                id: newerId,
                name: "Newer",
                kind: .regular,
                createdAt: newerDate,
                updatedAt: newerDate,
                sortOrder: nil,
                isDeleted: false
            )
        )

        let created = try store.createTrackList(
            id: UUID(),
            name: "Created",
            kind: .regular,
            createdAt: createdDate,
            tracks: []
        )

        XCTAssertEqual(try store.fetchMetas().map(\.id), [created.id, newerId, olderId])
        XCTAssertEqual(try trackListStore.fetch(id: created.id)?.sortOrder, 0)
        XCTAssertEqual(try trackListStore.fetch(id: newerId)?.sortOrder, 1)
        XCTAssertEqual(try trackListStore.fetch(id: olderId)?.sortOrder, 2)
    }

    func testLibraryDatabaseStorePersistsLibraryGraph() throws {
        let database = try makeDatabase()
        let store = try LibraryDatabaseStore(database: database)
        let rootFolderId = UUID()
        let childFolderId = UUID()
        let trackId = UUID()
        let now = Date()

        try store.upsertRootFolder(
            id: rootFolderId,
            name: "Music"
        )
        try store.upsertRootFolderBookmark(
            id: rootFolderId,
            bookmarkBase64: "root-bookmark"
        )
        try store.upsertLibraryTrack(
            id: trackId,
            fileName: "Track.mp3",
            relativePath: "Album/Track.mp3",
            folderId: childFolderId,
            rootFolderId: rootFolderId,
            fileDate: now,
            bookmarkBase64: "track-bookmark"
        )

        XCTAssertEqual(try store.fetchRootFolders().first?.name, "Music")
        XCTAssertEqual(try store.folderBookmark(id: rootFolderId), "root-bookmark")
        XCTAssertEqual(try store.fetchLibraryTracks(inFolder: childFolderId).map(\.id), [trackId])
        XCTAssertEqual(
            try store.fetchLibraryTrack(
                rootFolderId: rootFolderId,
                relativePath: "Album/Track.mp3"
            )?.id,
            trackId
        )
        XCTAssertEqual(try store.trackBookmark(id: trackId), "track-bookmark")

        let metadata = TrackMetadataDatabaseModel(
            trackId: trackId,
            title: "Title",
            artist: "Artist",
            album: "Album",
            albumArtist: nil,
            label: nil,
            genre: nil,
            year: 2026,
            trackNumber: 1,
            discNumber: nil,
            bpm: nil,
            keySignature: nil,
            comment: nil,
            duration: 120,
            bitrate: nil,
            sampleRate: nil,
            channelCount: nil,
            metadataUpdatedAt: now
        )
        try store.upsertTrackMetadata(metadata)
        XCTAssertEqual(try store.fetchTrackMetadata(trackId: trackId)?.title, "Title")

        try store.removeTrack(id: trackId)
        XCTAssertNil(try store.fetchLibraryTrack(id: trackId))
    }

    func testLibraryDatabaseStorePersistsManualRootFolderOrder() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = LibraryDatabaseStore(executor: executor)
        let folderStore = SQLiteFolderStore(executor: executor)
        let firstId = UUID()
        let secondId = UUID()
        let thirdId = UUID()

        try store.upsertRootFolder(
            id: firstId,
            name: "First"
        )
        try store.upsertRootFolder(
            id: secondId,
            name: "Second"
        )
        try store.upsertRootFolder(
            id: thirdId,
            name: "Third"
        )

        XCTAssertEqual(try store.fetchRootFolders().map(\.id), [thirdId, secondId, firstId])

        try store.updateRootFoldersOrder([firstId, thirdId, secondId])

        XCTAssertEqual(try store.fetchRootFolders().map(\.id), [firstId, thirdId, secondId])
        XCTAssertEqual(try folderStore.fetch(id: firstId)?.sortOrder, 0)
        XCTAssertEqual(try folderStore.fetch(id: thirdId)?.sortOrder, 1)
        XCTAssertEqual(try folderStore.fetch(id: secondId)?.sortOrder, 2)

        let reloadedStore = LibraryDatabaseStore(executor: executor)
        XCTAssertEqual(
            try reloadedStore.fetchRootFolders().map(\.id),
            [firstId, thirdId, secondId]
        )

        let fourthId = UUID()
        try reloadedStore.upsertRootFolder(
            id: fourthId,
            name: "Fourth"
        )

        // Добавление новой папки не меняет сохранённую относительную последовательность существующих папок.
        XCTAssertEqual(
            try reloadedStore.fetchRootFolders().map(\.id),
            [fourthId, firstId, thirdId, secondId]
        )
    }

    func testLibraryTrackSortModePersistsSeparatelyFromRootFolderOrder() throws {
        let database = try makeDatabase()
        let store = try LibraryDatabaseStore(database: database)
        let folderId = UUID()

        try store.upsertRootFolder(
            id: folderId,
            name: "Music"
        )
        try store.updateLibraryTrackSortMode(
            .titleAsc,
            forFolderId: folderId
        )

        let reloadedStore = try LibraryDatabaseStore(database: database)
        XCTAssertEqual(
            try reloadedStore.libraryTrackSortMode(forFolderId: folderId),
            .titleAsc
        )
    }

    func testFetchRootFoldersFallsBackToCreatedAtWhenSortOrderIsNil() throws {
        let database = try makeDatabase()
        let folderStore = try SQLiteFolderStore(database: database)
        let olderId = UUID()
        let newerId = UUID()
        let olderDate = Date(timeIntervalSince1970: 100)
        let newerDate = Date(timeIntervalSince1970: 200)

        // Старые записи могут не иметь sort_order, поэтому fetchRootFolders использует дату добавления.
        try folderStore.upsert(
            FolderDatabaseModel(
                id: olderId,
                parentFolderId: nil,
                rootFolderId: nil,
                name: "Older",
                relativePath: "",
                bookmarkBase64: nil,
                isRoot: true,
                isAvailable: true,
                createdAt: olderDate,
                updatedAt: olderDate,
                sortOrder: nil,
                lastScannedAt: nil,
                trackSortMode: nil
            )
        )
        try folderStore.upsert(
            FolderDatabaseModel(
                id: newerId,
                parentFolderId: nil,
                rootFolderId: nil,
                name: "Newer",
                relativePath: "",
                bookmarkBase64: nil,
                isRoot: true,
                isAvailable: true,
                createdAt: newerDate,
                updatedAt: newerDate,
                sortOrder: nil,
                lastScannedAt: nil,
                trackSortMode: nil
            )
        )

        XCTAssertEqual(try folderStore.fetchRootFolders().map(\.id), [newerId, olderId])
    }

    func testImportedTrackPersistsInSQLiteTracks() throws {
        let database = try makeDatabase()
        let store = try LibraryDatabaseStore(database: database)
        let trackId = UUID()
        let fileURL = try makeTemporaryAudioFile(name: "Imported.mp3")
        let now = Date()

        try store.upsertImportedTrack(
            id: trackId,
            fileName: fileURL.lastPathComponent,
            fileURL: fileURL,
            fileDate: now
        )

        let stored = try XCTUnwrap(store.fetchTrack(id: trackId))
        XCTAssertEqual(stored.source, .imported)
        XCTAssertNil(stored.folderId)
        XCTAssertNil(stored.rootFolderId)
        XCTAssertNil(stored.relativePath)
        XCTAssertEqual(stored.fileName, "Imported.mp3")
        XCTAssertEqual(stored.assetURLString, fileURL.standardizedFileURL.absoluteString)
    }

    func testImportedBookmarkPersistsInSQLiteTrackRow() throws {
        let database = try makeDatabase()
        let store = try LibraryDatabaseStore(database: database)
        let trackId = UUID()
        let fileURL = try makeTemporaryAudioFile(name: "Bookmark.mp3")

        try store.upsertImportedTrack(
            id: trackId,
            fileName: fileURL.lastPathComponent,
            fileURL: fileURL
        )
        try store.upsertTrackBookmark(
            id: trackId,
            bookmarkBase64: "imported-bookmark"
        )

        XCTAssertEqual(try store.trackBookmark(id: trackId), "imported-bookmark")
    }

    func testImportedTrackIdentityReturnsStableUUID() async throws {
        let database = try makeDatabase()
        let resolver = TrackIdentityResolver(database: database)
        let fileURL = try makeTemporaryAudioFile(name: "Stable.mp3")

        let firstId = try await resolver.trackId(forImportedURL: fileURL)
        let secondId = try await resolver.trackId(forImportedURL: fileURL)

        XCTAssertEqual(firstId, secondId)
        let stored = try XCTUnwrap(try LibraryDatabaseStore(database: database).fetchImportedTrack(id: firstId))
        XCTAssertEqual(stored.source, .imported)
    }

    func testImportedTrackIdentityForgetRemovesKeys() async throws {
        let database = try makeDatabase()
        let resolver = TrackIdentityResolver(database: database)
        let identityStore = try TrackIdentityDatabaseStore(database: database)
        let fileURL = try makeTemporaryAudioFile(name: "Forget.mp3")
        let identityKey = importedIdentityKey(for: fileURL)

        let trackId = try await resolver.trackId(forImportedURL: fileURL)
        XCTAssertNotNil(try identityStore.identity(identityKey: identityKey))

        try await resolver.forgetTrack(id: trackId)

        XCTAssertNil(try identityStore.identity(identityKey: identityKey))
    }

    func testImportedTrackIdentityReplaceRemovesOldPathKey() async throws {
        let database = try makeDatabase()
        let resolver = TrackIdentityResolver(database: database)
        let identityStore = try TrackIdentityDatabaseStore(database: database)
        let oldURL = try makeTemporaryAudioFile(name: "OldName.mp3")
        let newURL = try makeTemporaryAudioFile(name: "NewName.mp3")
        let oldIdentityKey = importedIdentityKey(for: oldURL)
        let newIdentityKey = importedIdentityKey(for: newURL)

        let trackId = try await resolver.trackId(forImportedURL: oldURL)
        try await resolver.replaceImportedTrackIdentity(id: trackId, url: newURL)

        XCTAssertNil(try identityStore.identity(identityKey: oldIdentityKey))
        XCTAssertEqual(try identityStore.identity(identityKey: newIdentityKey)?.trackId, trackId)

        let stored = try XCTUnwrap(try LibraryDatabaseStore(database: database).fetchImportedTrack(id: trackId))
        XCTAssertEqual(stored.fileName, "NewName.mp3")
        XCTAssertEqual(stored.assetURLString, newURL.standardizedFileURL.absoluteString)
    }

    func testBookmarkResolverResolvesImportedTrackFromSQLite() async throws {
        let database = try makeDatabase()
        let resolver = TrackIdentityResolver(database: database)
        let registry = TrackRegistry(database: database)
        let bookmarks = BookmarksRegistry(database: database)
        let fileURL = try makeTemporaryAudioFile(name: "Resolve.mp3")
        let trackId = try await resolver.trackId(forImportedURL: fileURL)
        let bookmark = try XCTUnwrap(BookmarkResolver.makeBookmarkBase64(for: fileURL))

        await bookmarks.upsertTrackBookmark(id: trackId, base64: bookmark)

        let resolvedURL = await BookmarkResolver.url(
            forTrack: trackId,
            trackRegistry: registry,
            bookmarksRegistry: bookmarks
        )

        XCTAssertEqual(resolvedURL?.standardizedFileURL.path, fileURL.standardizedFileURL.path)
    }

    func testTrackRegistryEntryReturnsImportedTrack() async throws {
        let database = try makeDatabase()
        let registry = TrackRegistry(database: database)
        let trackId = UUID()
        let fileURL = try makeTemporaryAudioFile(name: "Registry.mp3")

        await registry.upsertImportedTrack(
            id: trackId,
            fileName: fileURL.lastPathComponent,
            fileURL: fileURL
        )

        let entry = await registry.entry(for: trackId)
        XCTAssertEqual(entry?.source, .imported)
        XCTAssertEqual(entry?.fileName, "Registry.mp3")
        XCTAssertNil(entry?.folderId)
        XCTAssertNil(entry?.rootFolderId)
        XCTAssertNil(entry?.relativePath)
    }

    func testRegistriesDoNotCreateJSONFiles() async throws {
        let database = try makeDatabase()
        let registry = TrackRegistry(database: database)
        let identityResolver = TrackIdentityResolver(database: database)
        let bookmarks = BookmarksRegistry(database: database)
        let fileURL = try makeTemporaryAudioFile(name: "NoJSON.mp3")
        let trackId = try await identityResolver.trackId(forImportedURL: fileURL)

        await registry.upsertImportedTrack(
            id: trackId,
            fileName: fileURL.lastPathComponent,
            fileURL: fileURL
        )
        await bookmarks.upsertTrackBookmark(id: trackId, base64: "bookmark")
        try await registry.throwPendingPersistenceError()
        try await bookmarks.throwPendingPersistenceError()

        let directory = try XCTUnwrap(databaseDirectory)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("TrackRegistry.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("TrackIdentityRegistry.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("BookmarksRegistry.json").path))
    }

    func testSettingsDatabaseStoreCreatesDefaultSettingsOnlyOnce() throws {
        let database = try makeDatabase()
        let store = try SettingsDatabaseStore(database: database)

        let initialSettings = try store.fetchSettings {
            nil
        }

        XCTAssertEqual(initialSettings, AppSettings.defaultValue)
        XCTAssertEqual(initialSettings.internalSettings.libraryRootDisplayMode, .folders)
        XCTAssertEqual(initialSettings.internalSettings.purchasedITunesTrackSortMode, .titleAsc)

        let reloadedSettings = try store.fetchSettings {
            nil
        }

        XCTAssertEqual(reloadedSettings, initialSettings)
    }

    func testSettingsDatabaseStoreSavesWorkingSettingsToSQLite() throws {
        let database = try makeDatabase()
        let store = try SettingsDatabaseStore(database: database)
        var settings = try store.fetchSettings {
            nil
        }

        settings.visible.metadata.isTagReadingEnabled = false
        settings.visible.library.isTrackListMembershipVisible = false
        settings.visible.library.isFileFormatVisible = false
        settings.visible.library.isPurchasedITunesSourceVisible = false
        settings.internalSettings.libraryRootDisplayMode = .tracks
        settings.internalSettings.purchasedITunesTrackSortMode = .dateAddedDesc
        settings.internalSettings.trackListsSortMode = .name

        try store.saveSettings(settings)

        let reloadedSettings = try store.fetchSettings {
            AppSettings.defaultValue
        }

        XCTAssertFalse(reloadedSettings.visible.metadata.isTagReadingEnabled)
        XCTAssertFalse(reloadedSettings.visible.library.isTrackListMembershipVisible)
        XCTAssertFalse(reloadedSettings.visible.library.isFileFormatVisible)
        XCTAssertFalse(reloadedSettings.visible.library.isPurchasedITunesSourceVisible)
        XCTAssertEqual(reloadedSettings.internalSettings.libraryRootDisplayMode, .tracks)
        XCTAssertEqual(reloadedSettings.internalSettings.purchasedITunesTrackSortMode, .dateAddedDesc)
        XCTAssertEqual(reloadedSettings.internalSettings.trackListsSortMode, .name)

        var foldersSettings = reloadedSettings
        foldersSettings.internalSettings.libraryRootDisplayMode = .folders
        try store.saveSettings(foldersSettings)

        XCTAssertEqual(
            try store.fetchSettings { AppSettings.defaultValue }
            .internalSettings.libraryRootDisplayMode,
            .folders
        )
    }

    func testSettingsDatabaseStorePersistsMiniPlayerPresentationState() throws {
        let database = try makeDatabase()
        let store = try SettingsDatabaseStore(database: database)
        let initialSettings = try store.fetchSettings {
            nil
        }

        XCTAssertFalse(initialSettings.internalSettings.isMiniPlayerExpanded)

        var expandedSettings = initialSettings
        expandedSettings.internalSettings.isMiniPlayerExpanded = true
        try store.saveSettings(expandedSettings)

        let reloadedExpandedSettings = try store.fetchSettings {
            AppSettings.defaultValue
        }
        XCTAssertTrue(reloadedExpandedSettings.internalSettings.isMiniPlayerExpanded)

        var collapsedSettings = reloadedExpandedSettings
        collapsedSettings.internalSettings.isMiniPlayerExpanded = false
        try store.saveSettings(collapsedSettings)

        let reloadedCollapsedSettings = try store.fetchSettings {
            AppSettings.defaultValue
        }
        XCTAssertFalse(reloadedCollapsedSettings.internalSettings.isMiniPlayerExpanded)
    }

    func testSQLiteAppSettingsStoreRejectsCorruptedMiniPlayerPresentationState() throws {
        let database = try makeDatabase()
        let settingsStore = try SettingsDatabaseStore(database: database)
        _ = try settingsStore.fetchSettings {
            nil
        }

        let executor = try database.databaseExecutor()
        try executor.write { database in
            // Отключаем проверку ограничения только в тесте, чтобы смоделировать повреждённую базу.
            try database.executeScript(
                """
                PRAGMA ignore_check_constraints = ON;
                UPDATE app_settings SET mini_player_expanded = 2 WHERE id = 1;
                """
            )
        }

        let appSettingsStore = try SQLiteAppSettingsStore(database: database)
        XCTAssertThrowsError(try appSettingsStore.fetch())
    }

    func testSettingsDatabaseStoreFallsBackToFoldersForMissingLibraryRootDisplayMode() throws {
        let database = try makeDatabase()
        let store = try SettingsDatabaseStore(database: database)
        var settings = try store.fetchSettings {
            nil
        }

        // NULL моделирует строку старой базы без сохранённого режима корня фонотеки.
        settings.visible.library.isPurchasedITunesSourceVisible = false
        try store.saveSettings(settings)

        let executor = try database.databaseExecutor()
        try executor.write { database in
            let statement = try database.prepare(
                "UPDATE library_view_settings SET library_root_display_mode = NULL WHERE id = 1;"
            )
            try statement.execute()
        }

        let reloadedSettings = try store.fetchSettings {
            AppSettings.defaultValue
        }

        XCTAssertEqual(reloadedSettings.internalSettings.libraryRootDisplayMode, .folders)
        XCTAssertFalse(reloadedSettings.visible.library.isPurchasedITunesSourceVisible)
    }

    #if DEBUG
    func testDatabaseDiagnosticsSnapshotCountsActualLibraryState() throws {
        let database = try makeDatabase()
        let store = try LibraryDatabaseStore(database: database)
        let diagnosticsStore = try DatabaseDiagnosticsStore(database: database)
        let musicRootId = UUID()
        let downloadsRootId = UUID()
        let albumFolderId = UUID()
        let firstTrackId = UUID()
        let secondTrackId = UUID()
        let now = Date()

        try store.upsertRootFolder(
            id: musicRootId,
            name: "Music"
        )
        try store.upsertRootFolder(
            id: downloadsRootId,
            name: "Downloads"
        )

        try store.upsertLibraryTrack(
            id: firstTrackId,
            fileName: "First.mp3",
            relativePath: "Album/First.mp3",
            folderId: albumFolderId,
            rootFolderId: musicRootId,
            fileDate: now
        )
        try store.upsertLibraryTrack(
            id: secondTrackId,
            fileName: "Second.mp3",
            relativePath: "Second.mp3",
            folderId: musicRootId,
            rootFolderId: musicRootId,
            fileDate: now,
            isAvailable: false
        )

        // Недоступность выставляется отдельными update-запросами, как это делает runtime-проверка bookmark'ов.
        try store.updateFolderAvailability(
            id: albumFolderId,
            isAvailable: false
        )
        try store.upsertTrackMetadata(
            TrackMetadataDatabaseModel(
                trackId: firstTrackId,
                title: "First",
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
                duration: nil,
                bitrate: nil,
                sampleRate: nil,
                channelCount: nil,
                metadataUpdatedAt: now
            )
        )

        let snapshot = try diagnosticsStore.librarySnapshot()
        let rootsByName = Dictionary(uniqueKeysWithValues: snapshot.rootFolders.map { ($0.name, $0) })

        XCTAssertEqual(snapshot.rootFoldersCount, 2)
        XCTAssertEqual(snapshot.foldersTotalCount, 3)
        XCTAssertEqual(snapshot.libraryTracksTotalCount, 2)
        XCTAssertEqual(snapshot.metadataRowsCount, 1)
        XCTAssertEqual(snapshot.unavailableFoldersCount, 1)
        XCTAssertEqual(snapshot.unavailableTracksCount, 1)
        XCTAssertEqual(rootsByName["Music"]?.tracksCount, 2)
        XCTAssertEqual(rootsByName["Music"]?.foldersCount, 2)
        XCTAssertEqual(rootsByName["Downloads"]?.tracksCount, 0)
        XCTAssertEqual(rootsByName["Downloads"]?.foldersCount, 1)
    }
    #endif

    private func makeDatabase(
        migrations: [DatabaseMigration] = DatabaseMigration.all
    ) throws -> AppDatabase {
        let directory = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("SQLiteDatabaseLayerTests-\(UUID().uuidString)", isDirectory: true)
        let databaseURL = directory.appendingPathComponent("TrackList.sqlite")
        let database = AppDatabase(
            location: DatabaseLocation(databaseURL: databaseURL),
            migrator: DatabaseMigrator(migrations: migrations)
        )

        try database.open()

        self.database = database
        self.databaseDirectory = directory

        return database
    }

    /// Возвращает число применений миграции в служебной таблице схемы.
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

    /// Создаёт SQLite-снимок элемента очереди с заданным источником.
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

    /// Создаёт runtime-модель очереди для проверки смешанных источников.
    private func makePlayerTrack(
        trackId: UUID,
        title: String,
        source: TrackSource,
        assetURL: URL?
    ) -> PlayerTrack {
        PlayerTrack(
            queueItemId: UUID(),
            trackId: trackId,
            title: title,
            artist: "Artist",
            album: "Album",
            artworkData: nil,
            duration: 180,
            fileName: "\(title).m4a",
            isAvailable: true,
            source: source,
            assetURL: assetURL
        )
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

    /// Создаёт строку SQLite-треклиста с явно заданным назначением для проверок ограничений и миграций.
    private func makeTrackListDatabaseModel(
        id: UUID,
        name: String,
        kind: DatabaseTrackListKind,
        createdAt: Date,
        isDeleted: Bool
    ) -> TrackListDatabaseModel {
        TrackListDatabaseModel(
            id: id,
            name: name,
            kind: kind,
            createdAt: createdAt,
            updatedAt: createdAt,
            sortOrder: nil,
            isDeleted: isDeleted
        )
    }

    private func makeTrackListTrack(
        listItemId: UUID,
        trackId: UUID,
        title: String
    ) -> Track {
        // Трек не создаётся в таблице tracks, чтобы проверить независимость снимка треклиста от фонотеки.
        Track(
            listItemId: listItemId,
            trackId: trackId,
            title: title,
            artist: "Artist",
            duration: 10,
            fileName: "\(title).mp3",
            isAvailable: true
        )
    }

    private func makeTemporaryAudioFile(name: String) throws -> URL {
        let directory = try XCTUnwrap(databaseDirectory)
        let fileURL = directory.appendingPathComponent(name)

        // Пустого файла достаточно для проверки bookmark и SQLite metadata.
        _ = FileManager.default.createFile(
            atPath: fileURL.path,
            contents: Data()
        )

        return fileURL
    }

    private func importedIdentityKey(for url: URL) -> String {
        let normalizedPath = url
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path

        return "imp:\(normalizedPath)"
    }

    private enum ExpectedRollbackError: Error {
        case rollback
    }
}

// Проверяет порядок вызовов ViewModel без обращения к SQLite.
@MainActor
private final class TrackListsLoadingOrderSpy: TrackListsManaging {
    enum Call: Equatable {
        case ensureFavorites
        case loadMetas
        case delete(UUID)
        case updateOrder([UUID])
    }

    private(set) var calls: [Call] = []
    private var metas: [TrackListMeta]

    init(metas: [TrackListMeta]) {
        self.metas = metas
    }

    func ensureFavoritesTrackList() throws -> TrackListMeta {
        calls.append(.ensureFavorites)

        guard let favorites = metas.first(where: { $0.kind == .favorites }) else {
            throw AppError.trackListNotFound
        }

        return favorites
    }

    func favoritesTrackList() throws -> TrackListMeta? {
        metas.first { $0.kind == .favorites }
    }

    func loadTrackListMetas() throws -> [TrackListMeta] {
        calls.append(.loadMetas)
        return metas
    }

    func deleteTrackList(id: UUID) throws {
        guard let index = metas.firstIndex(where: { $0.id == id }) else {
            throw AppError.trackListNotFound
        }

        calls.append(.delete(id))
        metas.remove(at: index)
    }

    func renameTrackList(id: UUID, to newName: String) throws {
        throw AppError.trackListNotFound
    }

    func updateTrackListsOrder(_ orderedIds: [UUID]) throws {
        calls.append(.updateOrder(orderedIds))
    }
}

// Возвращает пустое содержимое треклиста, чтобы проверить только порядок загрузки метаданных.
@MainActor
private final class TrackListLoadingOrderSpy: TrackListManaging {
    func loadTracks(for id: UUID) throws -> [Track] {
        []
    }

    func saveTracks(_ tracks: [Track], for id: UUID) -> Bool {
        true
    }
}

// Не показывает интерфейсные ошибки в модульном тесте порядка загрузки.
@MainActor
private final class TrackListsToastPresenterSpy: ToastPresenting {
    func handle(_ event: ToastEvent, duration: TimeInterval) {}

    func handle(_ error: AppError) {}
}

extension TrackListsToastPresenterSpy: TrackListsLoadFailurePresenting {

    func presentTrackListsLoadFailure(_ error: AppError) {}
}

// Не меняет реальную sidebar-навигацию в изолированной проверке загрузки master-снимка.
@MainActor
private final class TrackListsNavigationPruningSpy: TrackListsNavigationPruning {

    func pruneTrackListSelection(validTrackListIDs: Set<UUID>) {}
}

// Предоставляет ViewModel минимальные настройки без обращения к рабочему глобальному объекту.
@MainActor
private final class TrackListsSettingsManagerSpy: SettingsManaging {
    @Published private var currentSettings = AppSettings.defaultValue

    var settings: AppSettings {
        currentSettings
    }

    var settingsPublisher: Published<AppSettings>.Publisher {
        $currentSettings
    }

    func setTagReadingEnabled(_ value: Bool) {
        currentSettings.visible.metadata.isTagReadingEnabled = value
    }

    func setTrackListMembershipVisible(_ value: Bool) {
        currentSettings.visible.library.isTrackListMembershipVisible = value
    }

    func setFileFormatVisible(_ value: Bool) {
        currentSettings.visible.library.isFileFormatVisible = value
    }

    func setPurchasedITunesSourceVisible(_ value: Bool) {
        currentSettings.visible.library.isPurchasedITunesSourceVisible = value
    }

    func setMiniPlayerExpanded(_ value: Bool) {
        currentSettings.internalSettings.isMiniPlayerExpanded = value
    }

    func setLibraryRootDisplayMode(_ mode: LibraryRootDisplayMode) throws {
        currentSettings.internalSettings.libraryRootDisplayMode = mode
    }

    func setLibraryTrackSortMode(_ mode: LibraryTrackSortMode) throws {
        currentSettings.internalSettings.libraryTrackSortMode = mode
    }

    func setTrackListsSortMode(_ mode: TrackListsSortMode?) throws {
        currentSettings.internalSettings.trackListsSortMode = mode
    }
}

// Не публикует внешние события, чтобы проверка была ограничена первой загрузкой ViewModel.
@MainActor
private final class TrackListsEventProviderSpy: TrackListsEventProviding {
    private let subject = PassthroughSubject<Void, Never>()

    var trackListsDidChange: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
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
