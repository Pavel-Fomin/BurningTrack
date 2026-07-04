//
//  SQLiteExportSettingsStore.swift
//  TrackList
//
//  Доступ к таблице export_settings.
//
//  Created by Codex on 04.07.2026.
//

import Foundation

// Читает единственную строку export_settings.
protocol ExportSettingsDatabaseReading {
    func fetch() throws -> ExportSettingsDatabaseModel?
}

// Записывает единственную строку export_settings.
protocol ExportSettingsDatabaseWriting {
    func insert(_ model: ExportSettingsDatabaseModel) throws
    func update(_ model: ExportSettingsDatabaseModel) throws
    func upsert(_ model: ExportSettingsDatabaseModel) throws
    func delete() throws
}

// SQLite-реализация доступа только к таблице export_settings.
final class SQLiteExportSettingsStore: ExportSettingsDatabaseReading, ExportSettingsDatabaseWriting {
    private let executor: DatabaseExecutor

    init(executor: DatabaseExecutor) {
        self.executor = executor
    }

    convenience init(database: AppDatabase = .shared) throws {
        try self.init(executor: database.databaseExecutor())
    }

    func fetch() throws -> ExportSettingsDatabaseModel? {
        try executor.read { database in
            let statement = try database.prepare(ExportSettingsDatabaseQueries.fetch)

            guard try statement.step() == .row else {
                return nil
            }

            return try Self.map(statement.rowReader())
        }
    }

    func insert(_ model: ExportSettingsDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(ExportSettingsDatabaseQueries.insert)
            try Self.bindInsert(model, statement: statement)
            try statement.execute()
        }
    }

    func update(_ model: ExportSettingsDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(ExportSettingsDatabaseQueries.update)
            try Self.bindUpdate(model, statement: statement)
            try statement.execute()
        }
    }

    func upsert(_ model: ExportSettingsDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(ExportSettingsDatabaseQueries.upsert)
            try Self.bindInsert(model, statement: statement)
            try statement.execute()
        }
    }

    func delete() throws {
        try executor.write { database in
            let statement = try database.prepare(ExportSettingsDatabaseQueries.delete)
            try statement.execute()
        }
    }

    private static func map(_ row: DatabaseRowReader) throws -> ExportSettingsDatabaseModel {
        let duplicateHandlingRawValue = try row.requiredString(at: 4)
        guard let duplicateHandling = DatabaseExportDuplicateHandling(rawValue: duplicateHandlingRawValue) else {
            throw DatabaseError.invalidColumnValue(column: DatabaseSchema.ExportSettings.duplicateHandling, value: duplicateHandlingRawValue)
        }

        return ExportSettingsDatabaseModel(
            id: try row.requiredInt(at: 0),
            filenameTemplate: try row.requiredString(at: 1),
            includeTrackListPrefix: try row.requiredBool(at: 2),
            prefixFormat: try row.requiredString(at: 3),
            duplicateHandling: duplicateHandling,
            createM3U: try row.requiredBool(at: 5),
            exportArtwork: try row.requiredBool(at: 6),
            updatedAt: try row.requiredDate(at: 7)
        )
    }

    private static func bindInsert(
        _ model: ExportSettingsDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // Порядок bind соответствует INSERT/UPSERT-запросу export_settings.
        try statement.bind(model.id, at: 1)
        try statement.bind(model.filenameTemplate, at: 2)
        try statement.bind(model.includeTrackListPrefix, at: 3)
        try statement.bind(model.prefixFormat, at: 4)
        try statement.bind(model.duplicateHandling.rawValue, at: 5)
        try statement.bind(model.createM3U, at: 6)
        try statement.bind(model.exportArtwork, at: 7)
        try statement.bind(model.updatedAt, at: 8)
    }

    private static func bindUpdate(
        _ model: ExportSettingsDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // UPDATE держит id последним, чтобы изменяемые поля шли в порядке схемы.
        try statement.bind(model.filenameTemplate, at: 1)
        try statement.bind(model.includeTrackListPrefix, at: 2)
        try statement.bind(model.prefixFormat, at: 3)
        try statement.bind(model.duplicateHandling.rawValue, at: 4)
        try statement.bind(model.createM3U, at: 5)
        try statement.bind(model.exportArtwork, at: 6)
        try statement.bind(model.updatedAt, at: 7)
        try statement.bind(model.id, at: 8)
    }
}
