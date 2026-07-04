//
//  SQLiteTrackListTrackStore.swift
//  TrackList
//
//  Доступ к таблице tracklist_tracks.
//
//  Created by Codex on 04.07.2026.
//

import Foundation

// Читает строки tracklist_tracks.
protocol TrackListTrackDatabaseReading {
    func fetch(id: UUID) throws -> TrackListTrackDatabaseModel?
    func fetchAll() throws -> [TrackListTrackDatabaseModel]
    func fetchAll(trackListId: UUID) throws -> [TrackListTrackDatabaseModel]
}

// Записывает строки tracklist_tracks и поддерживает атомарную замену порядка.
protocol TrackListTrackDatabaseWriting {
    func insert(_ model: TrackListTrackDatabaseModel) throws
    func update(_ model: TrackListTrackDatabaseModel) throws
    func upsert(_ model: TrackListTrackDatabaseModel) throws
    func delete(id: UUID) throws
    func replaceAll(_ models: [TrackListTrackDatabaseModel], forTrackListId trackListId: UUID) throws
}

// SQLite-реализация доступа только к таблице tracklist_tracks.
final class SQLiteTrackListTrackStore: TrackListTrackDatabaseReading, TrackListTrackDatabaseWriting {
    private let executor: DatabaseExecutor

    init(executor: DatabaseExecutor) {
        self.executor = executor
    }

    convenience init(database: AppDatabase = .shared) throws {
        try self.init(executor: database.databaseExecutor())
    }

    func fetch(id: UUID) throws -> TrackListTrackDatabaseModel? {
        try executor.read { database in
            let statement = try database.prepare(TrackListTrackDatabaseQueries.fetch)
            try statement.bind(id, at: 1)

            guard try statement.step() == .row else {
                return nil
            }

            return try Self.map(statement.rowReader())
        }
    }

    func fetchAll() throws -> [TrackListTrackDatabaseModel] {
        try executor.fetchAll(TrackListTrackDatabaseQueries.fetchAll, map: Self.map)
    }

    func fetchAll(trackListId: UUID) throws -> [TrackListTrackDatabaseModel] {
        try executor.read { database in
            let statement = try database.prepare(TrackListTrackDatabaseQueries.fetchAllForTrackList)
            try statement.bind(trackListId, at: 1)

            var result: [TrackListTrackDatabaseModel] = []
            while try statement.step() == .row {
                result.append(try Self.map(statement.rowReader()))
            }

            return result
        }
    }

    func insert(_ model: TrackListTrackDatabaseModel) throws {
        try executor.write { database in
            try Self.insert(model, database: database)
        }
    }

    func update(_ model: TrackListTrackDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(TrackListTrackDatabaseQueries.update)
            try Self.bindUpdate(model, statement: statement)
            try statement.execute()
        }
    }

    func upsert(_ model: TrackListTrackDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(TrackListTrackDatabaseQueries.upsert)
            try Self.bindInsert(model, statement: statement)
            try statement.execute()
        }
    }

    func delete(id: UUID) throws {
        try executor.write { database in
            let statement = try database.prepare(TrackListTrackDatabaseQueries.delete)
            try statement.bind(id, at: 1)
            try statement.execute()
        }
    }

    func replaceAll(
        _ models: [TrackListTrackDatabaseModel],
        forTrackListId trackListId: UUID
    ) throws {
        try executor.transaction { database in
            let deleteStatement = try database.prepare(TrackListTrackDatabaseQueries.deleteForTrackList)
            try deleteStatement.bind(trackListId, at: 1)
            try deleteStatement.execute()

            for model in models {
                try Self.insert(model, database: database)
            }
        }
    }

    private static func insert(
        _ model: TrackListTrackDatabaseModel,
        database: DatabaseConnection
    ) throws {
        let statement = try database.prepare(TrackListTrackDatabaseQueries.insert)
        try bindInsert(model, statement: statement)
        try statement.execute()
    }

    private static func map(_ row: DatabaseRowReader) throws -> TrackListTrackDatabaseModel {
        let sourceRawValue = try row.requiredString(at: 4)
        guard let source = DatabaseTrackSource(rawValue: sourceRawValue) else {
            throw DatabaseError.invalidColumnValue(column: DatabaseSchema.TrackListTracks.sourceSnapshot, value: sourceRawValue)
        }

        return TrackListTrackDatabaseModel(
            id: try row.requiredUUID(at: 0),
            trackListId: try row.requiredUUID(at: 1),
            trackId: try row.requiredUUID(at: 2),
            position: try row.requiredInt(at: 3),
            sourceSnapshot: source,
            titleSnapshot: row.string(at: 5),
            artistSnapshot: row.string(at: 6),
            albumSnapshot: row.string(at: 7),
            durationSnapshot: row.double(at: 8),
            fileNameSnapshot: row.string(at: 9),
            assetURLSnapshot: row.string(at: 10),
            isAvailableSnapshot: try row.requiredBool(at: 11),
            createdAt: try row.requiredDate(at: 12)
        )
    }

    private static func bindInsert(
        _ model: TrackListTrackDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // Порядок bind соответствует INSERT/UPSERT-запросу tracklist_tracks.
        try statement.bind(model.id, at: 1)
        try statement.bind(model.trackListId, at: 2)
        try statement.bind(model.trackId, at: 3)
        try statement.bind(model.position, at: 4)
        try statement.bind(model.sourceSnapshot.rawValue, at: 5)
        try statement.bind(model.titleSnapshot, at: 6)
        try statement.bind(model.artistSnapshot, at: 7)
        try statement.bind(model.albumSnapshot, at: 8)
        try statement.bind(model.durationSnapshot, at: 9)
        try statement.bind(model.fileNameSnapshot, at: 10)
        try statement.bind(model.assetURLSnapshot, at: 11)
        try statement.bind(model.isAvailableSnapshot, at: 12)
        try statement.bind(model.createdAt, at: 13)
    }

    private static func bindUpdate(
        _ model: TrackListTrackDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // UPDATE держит id последним, чтобы изменяемые поля шли в порядке схемы.
        try statement.bind(model.trackListId, at: 1)
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
        try statement.bind(model.id, at: 13)
    }
}
