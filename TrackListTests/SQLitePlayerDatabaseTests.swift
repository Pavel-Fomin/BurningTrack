//
//  SQLitePlayerDatabaseTests.swift
//  TrackList
//
//  Проверки SQLite-персистентности очереди, состояния и режима Player.
//
//  Created by Pavel Fomin on 22.08.2026.
//

import XCTest
@testable import TrackList

final class SQLitePlayerDatabaseTests: SQLiteDatabaseTestCase {
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
}
