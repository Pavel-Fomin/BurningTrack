//
//  SQLiteFolderStore.swift
//  TrackList
//
//  Доступ к таблице folders.
//
//  Created by Codex on 04.07.2026.
//

import Foundation

// SQLite-реализация доступа только к таблице folders.
final class SQLiteFolderStore {
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

    func fetchRootFolders() throws -> [FolderDatabaseModel] {
        try executor.fetchAll(FolderDatabaseQueries.fetchRootFolders, map: Self.map)
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

    /// Обновляет ручной порядок только для корневой папки фонотеки.
    func updateSortOrder(id: UUID, sortOrder: Int, updatedAt: Date) throws {
        try executor.write { database in
            let statement = try database.prepare(FolderDatabaseQueries.updateSortOrder)
            try statement.bind(sortOrder, at: 1)
            try statement.bind(updatedAt, at: 2)
            try statement.bind(id, at: 3)
            try statement.execute()
        }
    }

    /// Сохраняет выбранный режим сортировки треков для конкретной папки фонотеки.
    func updateTrackSortMode(
        id: UUID,
        trackSortMode: String,
        updatedAt: Date
    ) throws {
        try executor.write { database in
            let statement = try database.prepare(FolderDatabaseQueries.updateTrackSortMode)
            try statement.bind(trackSortMode, at: 1)
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
            sortOrder: row.int(at: 10),
            lastScannedAt: try row.date(at: 11),
            trackSortMode: row.string(at: 12)
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
        try statement.bind(model.sortOrder, at: 11)
        try statement.bind(model.lastScannedAt, at: 12)
        try statement.bind(model.trackSortMode, at: 13)
    }

}
