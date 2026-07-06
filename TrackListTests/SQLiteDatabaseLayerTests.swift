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
        settings.internalSettings.trackListsSortMode = .name

        try store.saveSettings(settings)

        let reloadedSettings = try store.fetchSettings {
            AppSettings.defaultValue
        }

        XCTAssertFalse(reloadedSettings.visible.metadata.isTagReadingEnabled)
        XCTAssertFalse(reloadedSettings.visible.library.isTrackListMembershipVisible)
        XCTAssertFalse(reloadedSettings.visible.library.isFileFormatVisible)
        XCTAssertFalse(reloadedSettings.visible.library.isPurchasedITunesSourceVisible)
        XCTAssertEqual(reloadedSettings.internalSettings.trackListsSortMode, .name)
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
                .trackListsSortModeSetting
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
