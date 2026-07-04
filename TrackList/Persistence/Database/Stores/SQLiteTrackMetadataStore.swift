//
//  SQLiteTrackMetadataStore.swift
//  TrackList
//
//  Доступ к таблице track_metadata.
//
//  Created by Codex on 04.07.2026.
//

import Foundation

// Читает сохранённые метаданные треков из SQLite.
protocol TrackMetadataDatabaseReading {
    func fetch(trackId: UUID) throws -> TrackMetadataDatabaseModel?
    func fetchAll() throws -> [TrackMetadataDatabaseModel]
}

// Записывает сохранённые метаданные треков в SQLite.
protocol TrackMetadataDatabaseWriting {
    func insert(_ model: TrackMetadataDatabaseModel) throws
    func update(_ model: TrackMetadataDatabaseModel) throws
    func upsert(_ model: TrackMetadataDatabaseModel) throws
    func delete(trackId: UUID) throws
}

// SQLite-реализация доступа только к таблице track_metadata.
final class SQLiteTrackMetadataStore: TrackMetadataDatabaseReading, TrackMetadataDatabaseWriting {
    private let executor: DatabaseExecutor

    init(executor: DatabaseExecutor) {
        self.executor = executor
    }

    convenience init(database: AppDatabase = .shared) throws {
        try self.init(executor: database.databaseExecutor())
    }

    func fetch(trackId: UUID) throws -> TrackMetadataDatabaseModel? {
        try executor.read { database in
            let statement = try database.prepare(TrackMetadataDatabaseQueries.fetch)
            try statement.bind(trackId, at: 1)

            guard try statement.step() == .row else {
                return nil
            }

            return try Self.map(statement.rowReader())
        }
    }

    func fetchAll() throws -> [TrackMetadataDatabaseModel] {
        try executor.fetchAll(TrackMetadataDatabaseQueries.fetchAll, map: Self.map)
    }

    func insert(_ model: TrackMetadataDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(TrackMetadataDatabaseQueries.insert)
            try Self.bindInsert(model, statement: statement)
            try statement.execute()
        }
    }

    func update(_ model: TrackMetadataDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(TrackMetadataDatabaseQueries.update)
            try Self.bindUpdate(model, statement: statement)
            try statement.execute()
        }
    }

    func upsert(_ model: TrackMetadataDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(TrackMetadataDatabaseQueries.upsert)
            try Self.bindInsert(model, statement: statement)
            try statement.execute()
        }
    }

    func delete(trackId: UUID) throws {
        try executor.write { database in
            let statement = try database.prepare(TrackMetadataDatabaseQueries.delete)
            try statement.bind(trackId, at: 1)
            try statement.execute()
        }
    }

    private static func map(_ row: DatabaseRowReader) throws -> TrackMetadataDatabaseModel {
        TrackMetadataDatabaseModel(
            trackId: try row.requiredUUID(at: 0),
            title: row.string(at: 1),
            artist: row.string(at: 2),
            album: row.string(at: 3),
            albumArtist: row.string(at: 4),
            genre: row.string(at: 5),
            year: row.int(at: 6),
            trackNumber: row.int(at: 7),
            discNumber: row.int(at: 8),
            bpm: row.double(at: 9),
            keySignature: row.string(at: 10),
            comment: row.string(at: 11),
            duration: row.double(at: 12),
            bitrate: row.int(at: 13),
            sampleRate: row.int(at: 14),
            channelCount: row.int(at: 15),
            metadataUpdatedAt: try row.requiredDate(at: 16)
        )
    }

    private static func bindInsert(
        _ model: TrackMetadataDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // Порядок bind соответствует INSERT/UPSERT-запросу track_metadata.
        try statement.bind(model.trackId, at: 1)
        try statement.bind(model.title, at: 2)
        try statement.bind(model.artist, at: 3)
        try statement.bind(model.album, at: 4)
        try statement.bind(model.albumArtist, at: 5)
        try statement.bind(model.genre, at: 6)
        try statement.bind(model.year, at: 7)
        try statement.bind(model.trackNumber, at: 8)
        try statement.bind(model.discNumber, at: 9)
        try statement.bind(model.bpm, at: 10)
        try statement.bind(model.keySignature, at: 11)
        try statement.bind(model.comment, at: 12)
        try statement.bind(model.duration, at: 13)
        try statement.bind(model.bitrate, at: 14)
        try statement.bind(model.sampleRate, at: 15)
        try statement.bind(model.channelCount, at: 16)
        try statement.bind(model.metadataUpdatedAt, at: 17)
    }

    private static func bindUpdate(
        _ model: TrackMetadataDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // UPDATE держит track_id последним, потому что это ключ строки.
        try statement.bind(model.title, at: 1)
        try statement.bind(model.artist, at: 2)
        try statement.bind(model.album, at: 3)
        try statement.bind(model.albumArtist, at: 4)
        try statement.bind(model.genre, at: 5)
        try statement.bind(model.year, at: 6)
        try statement.bind(model.trackNumber, at: 7)
        try statement.bind(model.discNumber, at: 8)
        try statement.bind(model.bpm, at: 9)
        try statement.bind(model.keySignature, at: 10)
        try statement.bind(model.comment, at: 11)
        try statement.bind(model.duration, at: 12)
        try statement.bind(model.bitrate, at: 13)
        try statement.bind(model.sampleRate, at: 14)
        try statement.bind(model.channelCount, at: 15)
        try statement.bind(model.metadataUpdatedAt, at: 16)
        try statement.bind(model.trackId, at: 17)
    }
}
