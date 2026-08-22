//
//  SQLiteLibraryDatabaseTests.swift
//  TrackList
//
//  Проверки SQLite-хранилища фонотеки и её снимков.
//
//  Created by Pavel Fomin on 22.08.2026.
//

import XCTest
@testable import TrackList

final class SQLiteLibraryDatabaseTests: SQLiteDatabaseTestCase {
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
}
