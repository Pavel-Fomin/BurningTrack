//
//  SQLitePlayerSettingsStore.swift
//  TrackList
//
//  Доступ к таблице player_settings.
//
//  Created by Codex on 04.07.2026.
//

import Foundation

// Читает единственную строку player_settings.
protocol PlayerSettingsDatabaseReading {
    func fetch() throws -> PlayerSettingsDatabaseModel?
}

// Записывает единственную строку player_settings.
protocol PlayerSettingsDatabaseWriting {
    func insert(_ model: PlayerSettingsDatabaseModel) throws
    func update(_ model: PlayerSettingsDatabaseModel) throws
    func upsert(_ model: PlayerSettingsDatabaseModel) throws
    func delete() throws
}

// SQLite-реализация доступа только к таблице player_settings.
final class SQLitePlayerSettingsStore: PlayerSettingsDatabaseReading, PlayerSettingsDatabaseWriting {
    private let executor: DatabaseExecutor

    init(executor: DatabaseExecutor) {
        self.executor = executor
    }

    convenience init(database: AppDatabase = .shared) throws {
        try self.init(executor: database.databaseExecutor())
    }

    func fetch() throws -> PlayerSettingsDatabaseModel? {
        try executor.read { database in
            let statement = try database.prepare(PlayerSettingsDatabaseQueries.fetch)

            guard try statement.step() == .row else {
                return nil
            }

            return try Self.map(statement.rowReader())
        }
    }

    func insert(_ model: PlayerSettingsDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(PlayerSettingsDatabaseQueries.insert)
            try Self.bindInsert(model, statement: statement)
            try statement.execute()
        }
    }

    func update(_ model: PlayerSettingsDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(PlayerSettingsDatabaseQueries.update)
            try Self.bindUpdate(model, statement: statement)
            try statement.execute()
        }
    }

    func upsert(_ model: PlayerSettingsDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(PlayerSettingsDatabaseQueries.upsert)
            try Self.bindInsert(model, statement: statement)
            try statement.execute()
        }
    }

    func delete() throws {
        try executor.write { database in
            let statement = try database.prepare(PlayerSettingsDatabaseQueries.delete)
            try statement.execute()
        }
    }

    private static func map(_ row: DatabaseRowReader) throws -> PlayerSettingsDatabaseModel {
        PlayerSettingsDatabaseModel(
            id: try row.requiredInt(at: 0),
            autoPlayNext: try row.requiredBool(at: 1),
            restoreLastPosition: try row.requiredBool(at: 2),
            showMiniPlayer: try row.requiredBool(at: 3),
            backgroundPlaybackEnabled: try row.requiredBool(at: 4),
            updatedAt: try row.requiredDate(at: 5)
        )
    }

    private static func bindInsert(
        _ model: PlayerSettingsDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // Порядок bind соответствует INSERT/UPSERT-запросу player_settings.
        try statement.bind(model.id, at: 1)
        try statement.bind(model.autoPlayNext, at: 2)
        try statement.bind(model.restoreLastPosition, at: 3)
        try statement.bind(model.showMiniPlayer, at: 4)
        try statement.bind(model.backgroundPlaybackEnabled, at: 5)
        try statement.bind(model.updatedAt, at: 6)
    }

    private static func bindUpdate(
        _ model: PlayerSettingsDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // UPDATE держит id последним, чтобы изменяемые поля шли в порядке схемы.
        try statement.bind(model.autoPlayNext, at: 1)
        try statement.bind(model.restoreLastPosition, at: 2)
        try statement.bind(model.showMiniPlayer, at: 3)
        try statement.bind(model.backgroundPlaybackEnabled, at: 4)
        try statement.bind(model.updatedAt, at: 5)
        try statement.bind(model.id, at: 6)
    }
}
