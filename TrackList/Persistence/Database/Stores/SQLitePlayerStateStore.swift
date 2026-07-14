//
//  SQLitePlayerStateStore.swift
//  TrackList
//
//  Доступ к таблице player_state.
//
//  Created by Codex on 04.07.2026.
//

import Foundation

// Читает единственную строку player_state.
protocol PlayerStateDatabaseReading {
    func fetch() throws -> PlayerStateDatabaseModel?
}

// Записывает единственную строку player_state.
protocol PlayerStateDatabaseWriting {
    func insert(_ model: PlayerStateDatabaseModel) throws
    func update(_ model: PlayerStateDatabaseModel) throws
    func upsert(_ model: PlayerStateDatabaseModel) throws
    func delete() throws
}

// SQLite-реализация доступа только к таблице player_state.
final class SQLitePlayerStateStore: PlayerStateDatabaseReading, PlayerStateDatabaseWriting {
    private let executor: DatabaseExecutor

    init(executor: DatabaseExecutor) {
        self.executor = executor
    }

    convenience init(database: AppDatabase = .shared) throws {
        try self.init(executor: database.databaseExecutor())
    }

    func fetch() throws -> PlayerStateDatabaseModel? {
        try executor.read { database in
            let statement = try database.prepare(PlayerStateDatabaseQueries.fetch)

            guard try statement.step() == .row else {
                return nil
            }

            return try Self.map(statement.rowReader())
        }
    }

    func insert(_ model: PlayerStateDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(PlayerStateDatabaseQueries.insert)
            try Self.bindInsert(model, statement: statement)
            try statement.execute()
        }
    }

    func update(_ model: PlayerStateDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(PlayerStateDatabaseQueries.update)
            try Self.bindUpdate(model, statement: statement)
            try statement.execute()
        }
    }

    func upsert(_ model: PlayerStateDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(PlayerStateDatabaseQueries.upsert)
            try Self.bindInsert(model, statement: statement)
            try statement.execute()
        }
    }

    func delete() throws {
        try executor.write { database in
            let statement = try database.prepare(PlayerStateDatabaseQueries.delete)
            try statement.execute()
        }
    }

    private static func map(_ row: DatabaseRowReader) throws -> PlayerStateDatabaseModel {
        let contextRawValue = try row.requiredString(at: 3)
        guard let contextType = DatabasePlaybackContextType(rawValue: contextRawValue) else {
            throw DatabaseError.invalidColumnValue(column: DatabaseSchema.PlayerState.contextType, value: contextRawValue)
        }

        let repeatRawValue = try row.requiredString(at: 8)
        guard let repeatMode = DatabaseRepeatMode(rawValue: repeatRawValue) else {
            throw DatabaseError.invalidColumnValue(
                column: DatabaseSchema.PlayerState.repeatMode,
                value: repeatRawValue
            )
        }

        return PlayerStateDatabaseModel(
            id: try row.requiredInt(at: 0),
            currentQueueItemId: try row.uuid(at: 1),
            currentTrackId: try row.uuid(at: 2),
            contextType: contextType,
            contextId: try row.uuid(at: 4),
            playbackTime: try row.requiredDouble(at: 5),
            duration: row.double(at: 6),
            isPlaying: try row.requiredBool(at: 7),
            repeatMode: repeatMode,
            shuffleEnabled: try row.requiredBool(at: 9),
            updatedAt: try row.requiredDate(at: 10)
        )
    }

    private static func bindInsert(
        _ model: PlayerStateDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // Порядок bind соответствует INSERT/UPSERT-запросу player_state.
        try statement.bind(model.id, at: 1)
        try statement.bind(model.currentQueueItemId, at: 2)
        try statement.bind(model.currentTrackId, at: 3)
        try statement.bind(model.contextType.rawValue, at: 4)
        try statement.bind(model.contextId, at: 5)
        try statement.bind(model.playbackTime, at: 6)
        try statement.bind(model.duration, at: 7)
        try statement.bind(model.isPlaying, at: 8)
        try statement.bind(model.repeatMode.rawValue, at: 9)
        try statement.bind(model.shuffleEnabled, at: 10)
        try statement.bind(model.updatedAt, at: 11)
    }

    private static func bindUpdate(
        _ model: PlayerStateDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // UPDATE держит id последним, чтобы изменяемые поля шли в порядке схемы.
        try statement.bind(model.currentQueueItemId, at: 1)
        try statement.bind(model.currentTrackId, at: 2)
        try statement.bind(model.contextType.rawValue, at: 3)
        try statement.bind(model.contextId, at: 4)
        try statement.bind(model.playbackTime, at: 5)
        try statement.bind(model.duration, at: 6)
        try statement.bind(model.isPlaying, at: 7)
        try statement.bind(model.repeatMode.rawValue, at: 8)
        try statement.bind(model.shuffleEnabled, at: 9)
        try statement.bind(model.updatedAt, at: 10)
        try statement.bind(model.id, at: 11)
    }
}
