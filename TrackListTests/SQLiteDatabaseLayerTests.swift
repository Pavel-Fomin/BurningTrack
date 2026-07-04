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

        try store.removeLibraryTrack(id: trackId)
        XCTAssertNil(try store.fetchLibraryTrack(id: trackId))
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
                .trackListTracksAllowExternalTrackIds
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

    private enum ExpectedRollbackError: Error {
        case rollback
    }
}
