//
//  SQLiteTrackListStore.swift
//  TrackList
//
//  Доступ к таблице tracklists.
//
//  Created by Codex on 04.07.2026.
//

import Foundation

// Читает строки tracklists.
protocol TrackListDatabaseReading {
    func fetch(id: UUID) throws -> TrackListDatabaseModel?
    func fetchAll() throws -> [TrackListDatabaseModel]
}

// Записывает строки tracklists.
protocol TrackListDatabaseWriting {
    func insert(_ model: TrackListDatabaseModel) throws
    func update(_ model: TrackListDatabaseModel) throws
    func upsert(_ model: TrackListDatabaseModel) throws
    func delete(id: UUID) throws
    func markDeleted(id: UUID, updatedAt: Date) throws
}

// SQLite-реализация доступа только к таблице tracklists.
final class SQLiteTrackListStore: TrackListDatabaseReading, TrackListDatabaseWriting {
    private let executor: DatabaseExecutor

    init(executor: DatabaseExecutor) {
        self.executor = executor
    }

    convenience init(database: AppDatabase = .shared) throws {
        try self.init(executor: database.databaseExecutor())
    }

    func fetch(id: UUID) throws -> TrackListDatabaseModel? {
        try executor.read { database in
            let statement = try database.prepare(TrackListDatabaseQueries.fetch)
            try statement.bind(id, at: 1)

            guard try statement.step() == .row else {
                return nil
            }

            return try Self.map(statement.rowReader())
        }
    }

    func fetchAll() throws -> [TrackListDatabaseModel] {
        try executor.fetchAll(TrackListDatabaseQueries.fetchAll, map: Self.map)
    }

    func insert(_ model: TrackListDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(TrackListDatabaseQueries.insert)
            try Self.bindInsert(model, statement: statement)
            try statement.execute()
        }
    }

    func update(_ model: TrackListDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(TrackListDatabaseQueries.update)
            try Self.bindUpdate(model, statement: statement)
            try statement.execute()
        }
    }

    func upsert(_ model: TrackListDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(TrackListDatabaseQueries.upsert)
            try Self.bindInsert(model, statement: statement)
            try statement.execute()
        }
    }

    func delete(id: UUID) throws {
        try executor.write { database in
            let statement = try database.prepare(TrackListDatabaseQueries.delete)
            try statement.bind(id, at: 1)
            try statement.execute()
        }
    }

    func markDeleted(id: UUID, updatedAt: Date) throws {
        try executor.write { database in
            let statement = try database.prepare(TrackListDatabaseQueries.markDeleted)
            try statement.bind(updatedAt, at: 1)
            try statement.bind(id, at: 2)
            try statement.execute()
        }
    }

    private static func map(_ row: DatabaseRowReader) throws -> TrackListDatabaseModel {
        TrackListDatabaseModel(
            id: try row.requiredUUID(at: 0),
            name: try row.requiredString(at: 1),
            createdAt: try row.requiredDate(at: 2),
            updatedAt: try row.requiredDate(at: 3),
            sortOrder: row.int(at: 4),
            isDeleted: try row.requiredBool(at: 5)
        )
    }

    private static func bindInsert(
        _ model: TrackListDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // Порядок bind соответствует INSERT/UPSERT-запросу tracklists.
        try statement.bind(model.id, at: 1)
        try statement.bind(model.name, at: 2)
        try statement.bind(model.createdAt, at: 3)
        try statement.bind(model.updatedAt, at: 4)
        try statement.bind(model.sortOrder, at: 5)
        try statement.bind(model.isDeleted, at: 6)
    }

    private static func bindUpdate(
        _ model: TrackListDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // UPDATE держит id последним, чтобы изменяемые поля шли в порядке схемы.
        try statement.bind(model.name, at: 1)
        try statement.bind(model.createdAt, at: 2)
        try statement.bind(model.updatedAt, at: 3)
        try statement.bind(model.sortOrder, at: 4)
        try statement.bind(model.isDeleted, at: 5)
        try statement.bind(model.id, at: 6)
    }
}
