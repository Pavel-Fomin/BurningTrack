//
//  SQLiteTrackIdentityTests.swift
//  TrackList
//
//  Проверки устойчивой идентичности local, imported и purchased iTunes-треков.
//
//  Created by Pavel Fomin on 22.08.2026.
//

import XCTest
@testable import TrackList

final class SQLiteTrackIdentityTests: SQLiteDatabaseTestCase {
    @MainActor
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
}
