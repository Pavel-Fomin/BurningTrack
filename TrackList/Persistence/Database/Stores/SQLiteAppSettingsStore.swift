//
//  SQLiteAppSettingsStore.swift
//  TrackList
//
//  Доступ к таблице app_settings.
//
//  Created by Codex on 04.07.2026.
//

import Foundation

// Читает единственную строку app_settings.
protocol AppSettingsDatabaseReading {
    func fetch() throws -> AppSettingsDatabaseModel?
}

// Записывает единственную строку app_settings.
protocol AppSettingsDatabaseWriting {
    func insert(_ model: AppSettingsDatabaseModel) throws
    func update(_ model: AppSettingsDatabaseModel) throws
    func upsert(_ model: AppSettingsDatabaseModel) throws
    func delete() throws
}

// SQLite-реализация доступа только к таблице app_settings.
final class SQLiteAppSettingsStore: AppSettingsDatabaseReading, AppSettingsDatabaseWriting {
    private let executor: DatabaseExecutor

    init(executor: DatabaseExecutor) {
        self.executor = executor
    }

    convenience init(database: AppDatabase = .shared) throws {
        try self.init(executor: database.databaseExecutor())
    }

    func fetch() throws -> AppSettingsDatabaseModel? {
        try executor.read { database in
            let statement = try database.prepare(AppSettingsDatabaseQueries.fetch)

            guard try statement.step() == .row else {
                return nil
            }

            return try Self.map(statement.rowReader())
        }
    }

    func insert(_ model: AppSettingsDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(AppSettingsDatabaseQueries.insert)
            try Self.bindInsert(model, statement: statement)
            try statement.execute()
        }
    }

    func update(_ model: AppSettingsDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(AppSettingsDatabaseQueries.update)
            try Self.bindUpdate(model, statement: statement)
            try statement.execute()
        }
    }

    func upsert(_ model: AppSettingsDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(AppSettingsDatabaseQueries.upsert)
            try Self.bindInsert(model, statement: statement)
            try statement.execute()
        }
    }

    func delete() throws {
        try executor.write { database in
            let statement = try database.prepare(AppSettingsDatabaseQueries.delete)
            try statement.execute()
        }
    }

    private static func map(_ row: DatabaseRowReader) throws -> AppSettingsDatabaseModel {
        let schemeRawValue = try row.requiredString(at: 2)
        guard let preferredColorScheme = DatabasePreferredColorScheme(rawValue: schemeRawValue) else {
            throw DatabaseError.invalidColumnValue(column: DatabaseSchema.AppSettings.preferredColorScheme, value: schemeRawValue)
        }

        return AppSettingsDatabaseModel(
            id: try row.requiredInt(at: 0),
            schemaVersion: try row.requiredInt(at: 1),
            preferredColorScheme: preferredColorScheme,
            accentColorName: row.string(at: 3),
            lastOpenedTab: row.string(at: 4),
            createdAt: try row.requiredDate(at: 5),
            updatedAt: try row.requiredDate(at: 6)
        )
    }

    private static func bindInsert(
        _ model: AppSettingsDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // Порядок bind соответствует INSERT/UPSERT-запросу app_settings.
        try statement.bind(model.id, at: 1)
        try statement.bind(model.schemaVersion, at: 2)
        try statement.bind(model.preferredColorScheme.rawValue, at: 3)
        try statement.bind(model.accentColorName, at: 4)
        try statement.bind(model.lastOpenedTab, at: 5)
        try statement.bind(model.createdAt, at: 6)
        try statement.bind(model.updatedAt, at: 7)
    }

    private static func bindUpdate(
        _ model: AppSettingsDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // UPDATE держит id последним, чтобы изменяемые поля шли в порядке схемы.
        try statement.bind(model.schemaVersion, at: 1)
        try statement.bind(model.preferredColorScheme.rawValue, at: 2)
        try statement.bind(model.accentColorName, at: 3)
        try statement.bind(model.lastOpenedTab, at: 4)
        try statement.bind(model.createdAt, at: 5)
        try statement.bind(model.updatedAt, at: 6)
        try statement.bind(model.id, at: 7)
    }
}
