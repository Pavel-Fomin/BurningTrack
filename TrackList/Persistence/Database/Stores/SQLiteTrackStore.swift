//
//  SQLiteTrackStore.swift
//  TrackList
//
//  Доступ к таблице tracks.
//
//  Created by Codex on 04.07.2026.
//

import Foundation

// SQLite-реализация доступа только к таблице tracks.
final class SQLiteTrackStore {
    private let executor: DatabaseExecutor

    init(executor: DatabaseExecutor) {
        self.executor = executor
    }

    convenience init(database: AppDatabase = .shared) throws {
        try self.init(executor: database.databaseExecutor())
    }

    func fetch(id: UUID) throws -> TrackDatabaseModel? {
        try executor.read { database in
            let statement = try database.prepare(TrackDatabaseQueries.fetch)
            try statement.bind(id, at: 1)

            guard try statement.step() == .row else {
                return nil
            }

            return try Self.map(statement.rowReader())
        }
    }

    func fetchLibrary(id: UUID) throws -> TrackDatabaseModel? {
        try executor.read { database in
            let statement = try database.prepare(TrackDatabaseQueries.fetchLibrary)
            try statement.bind(id, at: 1)

            guard try statement.step() == .row else {
                return nil
            }

            return try Self.map(statement.rowReader())
        }
    }

    func fetchImported(id: UUID) throws -> TrackDatabaseModel? {
        try executor.read { database in
            let statement = try database.prepare(TrackDatabaseQueries.fetchImported)
            try statement.bind(id, at: 1)

            guard try statement.step() == .row else {
                return nil
            }

            return try Self.map(statement.rowReader())
        }
    }

    func fetchActiveLocal(id: UUID) throws -> TrackDatabaseModel? {
        try executor.read { database in
            let statement = try database.prepare(TrackDatabaseQueries.fetchActiveLocal)
            try statement.bind(id, at: 1)

            guard try statement.step() == .row else {
                return nil
            }

            return try Self.map(statement.rowReader())
        }
    }

    func fetchAllActiveLocal() throws -> [TrackDatabaseModel] {
        try executor.fetchAll(TrackDatabaseQueries.fetchAllActiveLocal, map: Self.map)
    }

    func fetchLibrary(rootFolderId: UUID, relativePath: String) throws -> TrackDatabaseModel? {
        try executor.read { database in
            let statement = try database.prepare(TrackDatabaseQueries.fetchLibraryByRootRelativePath)
            try statement.bind(rootFolderId, at: 1)
            try statement.bind(relativePath, at: 2)

            guard try statement.step() == .row else {
                return nil
            }

            return try Self.map(statement.rowReader())
        }
    }

    func fetchLibraryTracks(inFolder folderId: UUID) throws -> [TrackDatabaseModel] {
        try executor.read { database in
            let statement = try database.prepare(TrackDatabaseQueries.fetchLibraryForFolder)
            try statement.bind(folderId, at: 1)

            var result: [TrackDatabaseModel] = []
            while try statement.step() == .row {
                result.append(try Self.map(statement.rowReader()))
            }

            return result
        }
    }

    func fetchLibraryTracks(inRootFolder rootFolderId: UUID) throws -> [TrackDatabaseModel] {
        try executor.read { database in
            let statement = try database.prepare(TrackDatabaseQueries.fetchLibraryForRoot)
            try statement.bind(rootFolderId, at: 1)

            var result: [TrackDatabaseModel] = []
            while try statement.step() == .row {
                result.append(try Self.map(statement.rowReader()))
            }

            return result
        }
    }

    func insert(_ model: TrackDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(TrackDatabaseQueries.insert)
            try Self.bindInsert(model, statement: statement)
            try statement.execute()
        }
    }

    func upsert(_ model: TrackDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(TrackDatabaseQueries.upsert)
            try Self.bindInsert(model, statement: statement)
            try statement.execute()
        }
    }

    func markDeleted(id: UUID, updatedAt: Date) throws {
        try executor.write { database in
            let statement = try database.prepare(TrackDatabaseQueries.markDeleted)
            try statement.bind(updatedAt, at: 1)
            try statement.bind(id, at: 2)
            try statement.execute()
        }
    }

    func updateBookmark(id: UUID, bookmarkBase64: String?, updatedAt: Date) throws {
        try executor.write { database in
            let statement = try database.prepare(TrackDatabaseQueries.updateBookmark)
            try statement.bind(bookmarkBase64, at: 1)
            try statement.bind(updatedAt, at: 2)
            try statement.bind(id, at: 3)
            try statement.execute()
        }
    }

    func updateAvailability(id: UUID, isAvailable: Bool, updatedAt: Date) throws {
        try executor.write { database in
            let statement = try database.prepare(TrackDatabaseQueries.updateAvailability)
            try statement.bind(isAvailable, at: 1)
            try statement.bind(updatedAt, at: 2)
            try statement.bind(id, at: 3)
            try statement.execute()
        }
    }

    private static func map(_ row: DatabaseRowReader) throws -> TrackDatabaseModel {
        let sourceRawValue = try row.requiredString(at: 1)
        guard let source = DatabaseTrackSource(rawValue: sourceRawValue) else {
            throw DatabaseError.invalidColumnValue(column: DatabaseSchema.Tracks.source, value: sourceRawValue)
        }

        return TrackDatabaseModel(
            id: try row.requiredUUID(at: 0),
            source: source,
            folderId: try row.uuid(at: 2),
            rootFolderId: try row.uuid(at: 3),
            fileName: try row.requiredString(at: 4),
            relativePath: row.string(at: 5),
            fileExtension: row.string(at: 6),
            fileSize: row.int64(at: 7),
            fileDate: try row.date(at: 8),
            importedAt: try row.requiredDate(at: 9),
            updatedAt: try row.requiredDate(at: 10),
            bookmarkBase64: row.string(at: 11),
            assetURLString: row.string(at: 12),
            isAvailable: try row.requiredBool(at: 13),
            isDeleted: try row.requiredBool(at: 14)
        )
    }

    private static func bindInsert(
        _ model: TrackDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // Порядок bind соответствует INSERT/UPSERT-запросу tracks.
        try statement.bind(model.id, at: 1)
        try statement.bind(model.source.rawValue, at: 2)
        try statement.bind(model.folderId, at: 3)
        try statement.bind(model.rootFolderId, at: 4)
        try statement.bind(model.fileName, at: 5)
        try statement.bind(model.relativePath, at: 6)
        try statement.bind(model.fileExtension, at: 7)
        try statement.bind(model.fileSize, at: 8)
        try statement.bind(model.fileDate, at: 9)
        try statement.bind(model.importedAt, at: 10)
        try statement.bind(model.updatedAt, at: 11)
        try statement.bind(model.bookmarkBase64, at: 12)
        try statement.bind(model.assetURLString, at: 13)
        try statement.bind(model.isAvailable, at: 14)
        try statement.bind(model.isDeleted, at: 15)
    }

}
