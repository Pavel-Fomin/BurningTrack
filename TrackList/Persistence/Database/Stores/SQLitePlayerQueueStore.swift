//
//  SQLitePlayerQueueStore.swift
//  TrackList
//
//  Доступ к таблице player_queue.
//
//  Created by Codex on 04.07.2026.
//

import Foundation

// Читает строки player_queue.
protocol PlayerQueueDatabaseReading {
    func fetch(id: UUID) throws -> PlayerQueueItemDatabaseModel?
    func fetchAll() throws -> [PlayerQueueItemDatabaseModel]
}

// Записывает строки player_queue и поддерживает атомарную замену очереди.
protocol PlayerQueueDatabaseWriting {
    func insert(_ model: PlayerQueueItemDatabaseModel) throws
    func update(_ model: PlayerQueueItemDatabaseModel) throws
    func upsert(_ model: PlayerQueueItemDatabaseModel) throws
    func delete(id: UUID) throws
    func replaceAll(_ models: [PlayerQueueItemDatabaseModel]) throws
}

// SQLite-реализация доступа только к таблице player_queue.
final class SQLitePlayerQueueStore: PlayerQueueDatabaseReading, PlayerQueueDatabaseWriting {
    private let executor: DatabaseExecutor

    init(executor: DatabaseExecutor) {
        self.executor = executor
    }

    convenience init(database: AppDatabase = .shared) throws {
        try self.init(executor: database.databaseExecutor())
    }

    func fetch(id: UUID) throws -> PlayerQueueItemDatabaseModel? {
        try executor.read { database in
            let statement = try database.prepare(PlayerQueueDatabaseQueries.fetch)
            try statement.bind(id, at: 1)

            guard try statement.step() == .row else {
                return nil
            }

            return try Self.map(statement.rowReader())
        }
    }

    func fetchAll() throws -> [PlayerQueueItemDatabaseModel] {
        try executor.fetchAll(PlayerQueueDatabaseQueries.fetchAll, map: Self.map)
    }

    func insert(_ model: PlayerQueueItemDatabaseModel) throws {
        try executor.write { database in
            try Self.insert(model, database: database)
        }
    }

    func update(_ model: PlayerQueueItemDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(PlayerQueueDatabaseQueries.update)
            try Self.bindUpdate(model, statement: statement)
            try statement.execute()
        }
    }

    func upsert(_ model: PlayerQueueItemDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(PlayerQueueDatabaseQueries.upsert)
            try Self.bindInsert(model, statement: statement)
            try statement.execute()
        }
    }

    func delete(id: UUID) throws {
        try executor.write { database in
            let statement = try database.prepare(PlayerQueueDatabaseQueries.delete)
            try statement.bind(id, at: 1)
            try statement.execute()
        }
    }

    func replaceAll(_ models: [PlayerQueueItemDatabaseModel]) throws {
        try executor.transaction { database in
            let deleteStatement = try database.prepare(PlayerQueueDatabaseQueries.deleteAll)
            try deleteStatement.execute()

            for model in models {
                try Self.insert(model, database: database)
            }
        }
    }

    private static func insert(
        _ model: PlayerQueueItemDatabaseModel,
        database: DatabaseConnection
    ) throws {
        let statement = try database.prepare(PlayerQueueDatabaseQueries.insert)
        try bindInsert(model, statement: statement)
        try statement.execute()
    }

    private static func map(_ row: DatabaseRowReader) throws -> PlayerQueueItemDatabaseModel {
        let sourceRawValue = try row.requiredString(at: 3)
        guard let source = DatabaseTrackSource(rawValue: sourceRawValue) else {
            throw DatabaseError.invalidColumnValue(column: DatabaseSchema.PlayerQueue.sourceSnapshot, value: sourceRawValue)
        }

        return PlayerQueueItemDatabaseModel(
            id: try row.requiredUUID(at: 0),
            trackId: try row.requiredUUID(at: 1),
            position: try row.requiredInt(at: 2),
            sourceSnapshot: source,
            titleSnapshot: row.string(at: 4),
            artistSnapshot: row.string(at: 5),
            albumSnapshot: row.string(at: 6),
            durationSnapshot: row.double(at: 7),
            fileNameSnapshot: row.string(at: 8),
            assetURLSnapshot: row.string(at: 9),
            isAvailableSnapshot: try row.requiredBool(at: 10),
            createdAt: try row.requiredDate(at: 11)
        )
    }

    private static func bindInsert(
        _ model: PlayerQueueItemDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // Порядок bind соответствует INSERT/UPSERT-запросу player_queue.
        try statement.bind(model.id, at: 1)
        try statement.bind(model.trackId, at: 2)
        try statement.bind(model.position, at: 3)
        try statement.bind(model.sourceSnapshot.rawValue, at: 4)
        try statement.bind(model.titleSnapshot, at: 5)
        try statement.bind(model.artistSnapshot, at: 6)
        try statement.bind(model.albumSnapshot, at: 7)
        try statement.bind(model.durationSnapshot, at: 8)
        try statement.bind(model.fileNameSnapshot, at: 9)
        try statement.bind(model.assetURLSnapshot, at: 10)
        try statement.bind(model.isAvailableSnapshot, at: 11)
        try statement.bind(model.createdAt, at: 12)
    }

    private static func bindUpdate(
        _ model: PlayerQueueItemDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // UPDATE держит id последним, чтобы изменяемые поля шли в порядке схемы.
        try statement.bind(model.trackId, at: 1)
        try statement.bind(model.position, at: 2)
        try statement.bind(model.sourceSnapshot.rawValue, at: 3)
        try statement.bind(model.titleSnapshot, at: 4)
        try statement.bind(model.artistSnapshot, at: 5)
        try statement.bind(model.albumSnapshot, at: 6)
        try statement.bind(model.durationSnapshot, at: 7)
        try statement.bind(model.fileNameSnapshot, at: 8)
        try statement.bind(model.assetURLSnapshot, at: 9)
        try statement.bind(model.isAvailableSnapshot, at: 10)
        try statement.bind(model.createdAt, at: 11)
        try statement.bind(model.id, at: 12)
    }
}
