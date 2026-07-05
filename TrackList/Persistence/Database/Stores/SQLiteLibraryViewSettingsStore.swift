//
//  SQLiteLibraryViewSettingsStore.swift
//  TrackList
//
//  Доступ к таблице library_view_settings.
//
//  Created by Codex on 04.07.2026.
//

import Foundation

// Читает единственную строку library_view_settings.
protocol LibraryViewSettingsDatabaseReading {
    func fetch() throws -> LibraryViewSettingsDatabaseModel?
}

// Записывает единственную строку library_view_settings.
protocol LibraryViewSettingsDatabaseWriting {
    func insert(_ model: LibraryViewSettingsDatabaseModel) throws
    func update(_ model: LibraryViewSettingsDatabaseModel) throws
    func upsert(_ model: LibraryViewSettingsDatabaseModel) throws
    func delete() throws
}

// SQLite-реализация доступа только к таблице library_view_settings.
final class SQLiteLibraryViewSettingsStore: LibraryViewSettingsDatabaseReading, LibraryViewSettingsDatabaseWriting {
    private let executor: DatabaseExecutor

    init(executor: DatabaseExecutor) {
        self.executor = executor
    }

    convenience init(database: AppDatabase = .shared) throws {
        try self.init(executor: database.databaseExecutor())
    }

    func fetch() throws -> LibraryViewSettingsDatabaseModel? {
        try executor.read { database in
            let statement = try database.prepare(LibraryViewSettingsDatabaseQueries.fetch)

            guard try statement.step() == .row else {
                return nil
            }

            return try Self.map(statement.rowReader())
        }
    }

    func insert(_ model: LibraryViewSettingsDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(LibraryViewSettingsDatabaseQueries.insert)
            try Self.bindInsert(model, statement: statement)
            try statement.execute()
        }
    }

    func update(_ model: LibraryViewSettingsDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(LibraryViewSettingsDatabaseQueries.update)
            try Self.bindUpdate(model, statement: statement)
            try statement.execute()
        }
    }

    func upsert(_ model: LibraryViewSettingsDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(LibraryViewSettingsDatabaseQueries.upsert)
            try Self.bindInsert(model, statement: statement)
            try statement.execute()
        }
    }

    func delete() throws {
        try executor.write { database in
            let statement = try database.prepare(LibraryViewSettingsDatabaseQueries.delete)
            try statement.execute()
        }
    }

    private static func map(_ row: DatabaseRowReader) throws -> LibraryViewSettingsDatabaseModel {
        LibraryViewSettingsDatabaseModel(
            id: try row.requiredInt(at: 0),
            sortMode: try row.requiredString(at: 1),
            groupMode: try row.requiredString(at: 2),
            showTrackListBadges: try row.requiredBool(at: 3),
            showUnavailableTracks: try row.requiredBool(at: 4),
            showFileFormat: try row.requiredBool(at: 5),
            showPurchasedITunesSource: try row.requiredBool(at: 6),
            lastOpenedFolderId: try row.uuid(at: 7),
            updatedAt: try row.requiredDate(at: 8)
        )
    }

    private static func bindInsert(
        _ model: LibraryViewSettingsDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // Порядок bind соответствует INSERT/UPSERT-запросу library_view_settings.
        try statement.bind(model.id, at: 1)
        try statement.bind(model.sortMode, at: 2)
        try statement.bind(model.groupMode, at: 3)
        try statement.bind(model.showTrackListBadges, at: 4)
        try statement.bind(model.showUnavailableTracks, at: 5)
        try statement.bind(model.showFileFormat, at: 6)
        try statement.bind(model.showPurchasedITunesSource, at: 7)
        try statement.bind(model.lastOpenedFolderId, at: 8)
        try statement.bind(model.updatedAt, at: 9)
    }

    private static func bindUpdate(
        _ model: LibraryViewSettingsDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // UPDATE держит id последним, чтобы изменяемые поля шли в порядке схемы.
        try statement.bind(model.sortMode, at: 1)
        try statement.bind(model.groupMode, at: 2)
        try statement.bind(model.showTrackListBadges, at: 3)
        try statement.bind(model.showUnavailableTracks, at: 4)
        try statement.bind(model.showFileFormat, at: 5)
        try statement.bind(model.showPurchasedITunesSource, at: 6)
        try statement.bind(model.lastOpenedFolderId, at: 7)
        try statement.bind(model.updatedAt, at: 8)
        try statement.bind(model.id, at: 9)
    }
}
