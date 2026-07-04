//
//  SQLiteFolderStore.swift
//  TrackList
//
//  Доступ к таблице folders.
//
//  Created by Codex on 04.07.2026.
//

import Foundation

// Читает строки folders без раскрытия SQLite остальному приложению.
protocol FolderDatabaseReading {
    func fetch(id: UUID) throws -> FolderDatabaseModel?
    func fetchAll() throws -> [FolderDatabaseModel]
    func fetchRootFolders() throws -> [FolderDatabaseModel]
    func fetchAll(rootFolderId: UUID) throws -> [FolderDatabaseModel]
    func fetch(rootFolderId: UUID, relativePath: String) throws -> FolderDatabaseModel?
}

// Записывает строки folders без смешивания с бизнес-логикой фонотеки.
protocol FolderDatabaseWriting {
    func insert(_ model: FolderDatabaseModel) throws
    func update(_ model: FolderDatabaseModel) throws
    func upsert(_ model: FolderDatabaseModel) throws
    func delete(id: UUID) throws
    func updateBookmark(id: UUID, bookmarkBase64: String?, updatedAt: Date) throws
    func updateAvailability(id: UUID, isAvailable: Bool, updatedAt: Date) throws
}

// SQLite-реализация доступа только к таблице folders.
final class SQLiteFolderStore: FolderDatabaseReading, FolderDatabaseWriting {
    private let executor: DatabaseExecutor

    init(executor: DatabaseExecutor) {
        self.executor = executor
    }

    convenience init(database: AppDatabase = .shared) throws {
        try self.init(executor: database.databaseExecutor())
    }

    func fetch(id: UUID) throws -> FolderDatabaseModel? {
        try executor.read { database in
            let statement = try database.prepare(FolderDatabaseQueries.fetch)
            try statement.bind(id, at: 1)

            guard try statement.step() == .row else {
                return nil
            }

            return try Self.map(statement.rowReader())
        }
    }

    func fetchAll() throws -> [FolderDatabaseModel] {
        try executor.fetchAll(FolderDatabaseQueries.fetchAll, map: Self.map)
    }

    func fetchRootFolders() throws -> [FolderDatabaseModel] {
        try executor.fetchAll(FolderDatabaseQueries.fetchRootFolders, map: Self.map)
    }

    func fetchAll(rootFolderId: UUID) throws -> [FolderDatabaseModel] {
        try executor.read { database in
            let statement = try database.prepare(FolderDatabaseQueries.fetchAllForRoot)
            try statement.bind(rootFolderId, at: 1)
            try statement.bind(rootFolderId, at: 2)

            var result: [FolderDatabaseModel] = []
            while try statement.step() == .row {
                result.append(try Self.map(statement.rowReader()))
            }

            return result
        }
    }

    func fetch(rootFolderId: UUID, relativePath: String) throws -> FolderDatabaseModel? {
        try executor.read { database in
            let statement = try database.prepare(FolderDatabaseQueries.fetchByRootRelativePath)
            try statement.bind(rootFolderId, at: 1)
            try statement.bind(relativePath, at: 2)

            guard try statement.step() == .row else {
                return nil
            }

            return try Self.map(statement.rowReader())
        }
    }

    func insert(_ model: FolderDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(FolderDatabaseQueries.insert)
            try Self.bindInsert(model, statement: statement)
            try statement.execute()
        }
    }

    func update(_ model: FolderDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(FolderDatabaseQueries.update)
            try Self.bindUpdate(model, statement: statement)
            try statement.execute()
        }
    }

    func upsert(_ model: FolderDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(FolderDatabaseQueries.upsert)
            try Self.bindInsert(model, statement: statement)
            try statement.execute()
        }
    }

    func delete(id: UUID) throws {
        try executor.write { database in
            let statement = try database.prepare(FolderDatabaseQueries.delete)
            try statement.bind(id, at: 1)
            try statement.execute()
        }
    }

    func updateBookmark(id: UUID, bookmarkBase64: String?, updatedAt: Date) throws {
        try executor.write { database in
            let statement = try database.prepare(FolderDatabaseQueries.updateBookmark)
            try statement.bind(bookmarkBase64, at: 1)
            try statement.bind(updatedAt, at: 2)
            try statement.bind(id, at: 3)
            try statement.execute()
        }
    }

    func updateAvailability(id: UUID, isAvailable: Bool, updatedAt: Date) throws {
        try executor.write { database in
            let statement = try database.prepare(FolderDatabaseQueries.updateAvailability)
            try statement.bind(isAvailable, at: 1)
            try statement.bind(updatedAt, at: 2)
            try statement.bind(id, at: 3)
            try statement.execute()
        }
    }

    private static func map(_ row: DatabaseRowReader) throws -> FolderDatabaseModel {
        FolderDatabaseModel(
            id: try row.requiredUUID(at: 0),
            parentFolderId: try row.uuid(at: 1),
            rootFolderId: try row.uuid(at: 2),
            name: try row.requiredString(at: 3),
            relativePath: try row.requiredString(at: 4),
            bookmarkBase64: row.string(at: 5),
            isRoot: try row.requiredBool(at: 6),
            isAvailable: try row.requiredBool(at: 7),
            createdAt: try row.requiredDate(at: 8),
            updatedAt: try row.requiredDate(at: 9),
            lastScannedAt: try row.date(at: 10)
        )
    }

    private static func bindInsert(
        _ model: FolderDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // Порядок bind соответствует INSERT/UPSERT-запросу folders.
        try statement.bind(model.id, at: 1)
        try statement.bind(model.parentFolderId, at: 2)
        try statement.bind(model.rootFolderId, at: 3)
        try statement.bind(model.name, at: 4)
        try statement.bind(model.relativePath, at: 5)
        try statement.bind(model.bookmarkBase64, at: 6)
        try statement.bind(model.isRoot, at: 7)
        try statement.bind(model.isAvailable, at: 8)
        try statement.bind(model.createdAt, at: 9)
        try statement.bind(model.updatedAt, at: 10)
        try statement.bind(model.lastScannedAt, at: 11)
    }

    private static func bindUpdate(
        _ model: FolderDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // UPDATE держит id последним, чтобы набор изменяемых колонок был читаемым.
        try statement.bind(model.parentFolderId, at: 1)
        try statement.bind(model.rootFolderId, at: 2)
        try statement.bind(model.name, at: 3)
        try statement.bind(model.relativePath, at: 4)
        try statement.bind(model.bookmarkBase64, at: 5)
        try statement.bind(model.isRoot, at: 6)
        try statement.bind(model.isAvailable, at: 7)
        try statement.bind(model.createdAt, at: 8)
        try statement.bind(model.updatedAt, at: 9)
        try statement.bind(model.lastScannedAt, at: 10)
        try statement.bind(model.id, at: 11)
    }
}
