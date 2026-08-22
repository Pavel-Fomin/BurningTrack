//
//  SQLiteDatabaseTestCase.swift
//  TrackList
//
//  Общий lifecycle временной SQLite-базы и переиспользуемые test fixtures.
//
//  Created by Pavel Fomin on 22.08.2026.
//

import XCTest
@testable import TrackList

class SQLiteDatabaseTestCase: XCTestCase {
    var database: AppDatabase?
    var databaseDirectory: URL?

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

    func makeDatabase(
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

    func makeTrack(fileName: String) -> TrackDatabaseModel {
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

    func makeTrackListDatabaseModel(
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

    func makeTrackListTrack(
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
}
