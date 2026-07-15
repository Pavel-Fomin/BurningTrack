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
            )
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
            createdAt: createdAt,
            tracks: [firstEntry, secondEntry]
        )

        XCTAssertEqual(try store.fetchMetas().map(\.id), [created.id])
        XCTAssertEqual(try store.fetchTracks(for: created.id).map(\.id), [firstEntry.id, secondEntry.id])
        XCTAssertEqual(try store.fetchTracks(for: created.id).map(\.trackId), [trackId, trackId])

        try store.replaceTracks([secondEntry], for: created.id)

        let remainingTracks = try store.fetchTrackList(id: created.id).tracks
        XCTAssertEqual(remainingTracks.map(\.id), [secondEntry.id])
        XCTAssertEqual(remainingTracks.first?.trackId, trackId)

        try store.renameTrackList(id: created.id, to: "Renamed")
        XCTAssertEqual(try store.fetchTrackList(id: created.id).name, "Renamed")

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
            createdAt: firstDate,
            tracks: []
        )
        let second = try store.createTrackList(
            id: UUID(),
            name: "Second",
            createdAt: secondDate,
            tracks: []
        )
        let third = try store.createTrackList(
            id: UUID(),
            name: "Third",
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
                createdAt: newerDate,
                updatedAt: newerDate,
                sortOrder: nil,
                isDeleted: false
            )
        )

        let created = try store.createTrackList(
            id: UUID(),
            name: "Created",
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
        settings.internalSettings.trackListsSortMode = .name
        settings.internalSettings.libraryFoldersSortMode = .createdAt

        try store.saveSettings(settings)

        let reloadedSettings = try store.fetchSettings {
            AppSettings.defaultValue
        }

        XCTAssertFalse(reloadedSettings.visible.metadata.isTagReadingEnabled)
        XCTAssertFalse(reloadedSettings.visible.library.isTrackListMembershipVisible)
        XCTAssertFalse(reloadedSettings.visible.library.isFileFormatVisible)
        XCTAssertFalse(reloadedSettings.visible.library.isPurchasedITunesSourceVisible)
        XCTAssertEqual(reloadedSettings.internalSettings.libraryRootDisplayMode, .tracks)
        XCTAssertEqual(reloadedSettings.internalSettings.trackListsSortMode, .name)
        XCTAssertEqual(reloadedSettings.internalSettings.libraryFoldersSortMode, .createdAt)

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

    private func makeDatabase() throws -> AppDatabase {
        let directory = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("SQLiteDatabaseLayerTests-\(UUID().uuidString)", isDirectory: true)
        let databaseURL = directory.appendingPathComponent("TrackList.sqlite")
        let database = AppDatabase(
            location: DatabaseLocation(databaseURL: databaseURL),
            migrator: DatabaseMigrator(migrations: [
                .initialSchema,
                .initialTables,
                .trackListTracksAllowExternalTrackIds,
                .settingsPhase7,
                .importedTracksPhase8,
                .trackListsSortModeSetting,
                .libraryFoldersSorting,
                .trackMetadataLabel,
                .folderTrackSortMode,
                .libraryRootDisplayModeSetting,
                .libraryRootDisplayModeColumnRepair,
                .playbackModeSettings,
                .miniPlayerPresentationState,
                .playerContextSource,
                .libraryPlaybackContextSource,
                .libraryCollectionPlaybackContextSource
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
