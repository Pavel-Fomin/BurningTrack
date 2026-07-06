//
//  SQLiteTrackMetadataStore.swift
//  TrackList
//
//  Доступ к таблице track_metadata.
//
//  Created by Codex on 04.07.2026.
//

import Foundation

// SQLite-реализация доступа только к таблице track_metadata.
final class SQLiteTrackMetadataStore {
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

    /// Возвращает metadata пачкой, чтобы экран фонотеки не делал N отдельных SQLite-запросов.
    func fetchAll(trackIds: [UUID]) throws -> [TrackMetadataDatabaseModel] {
        let uniqueTrackIds = orderedUniqueTrackIds(trackIds)
        guard uniqueTrackIds.isEmpty == false else { return [] }

        var result: [TrackMetadataDatabaseModel] = []
        result.reserveCapacity(uniqueTrackIds.count)

        for startIndex in stride(from: 0, to: uniqueTrackIds.count, by: Constants.maxBoundIdsPerQuery) {
            let endIndex = min(startIndex + Constants.maxBoundIdsPerQuery, uniqueTrackIds.count)
            let chunk = Array(uniqueTrackIds[startIndex..<endIndex])
            result.append(contentsOf: try fetchChunk(trackIds: chunk))
        }

        return result
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
            label: row.string(at: 5),
            genre: row.string(at: 6),
            year: yearValue(from: row, at: 7),
            trackNumber: row.int(at: 8),
            discNumber: row.int(at: 9),
            bpm: row.double(at: 10),
            keySignature: row.string(at: 11),
            comment: row.string(at: 12),
            duration: row.double(at: 13),
            bitrate: row.int(at: 14),
            sampleRate: row.int(at: 15),
            channelCount: row.int(at: 16),
            metadataUpdatedAt: try row.requiredDate(at: 17)
        )
    }

    /// Читает год как число или строку с годом в начале, оставляя некорректные значения пустыми.
    private static func yearValue(
        from row: DatabaseRowReader,
        at index: Int32
    ) -> Int? {
        guard let rawValue = row.string(at: index)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            rawValue.isEmpty == false else {
            return nil
        }

        if let exactYear = Int(rawValue) {
            return exactYear
        }

        let leadingDigits = rawValue.prefix { character in
            character.isNumber
        }

        guard leadingDigits.count == 4 else { return nil }
        return Int(leadingDigits)
    }

    /// Читает одну пачку trackId внутри лимита bind-параметров SQLite.
    private func fetchChunk(trackIds: [UUID]) throws -> [TrackMetadataDatabaseModel] {
        try executor.read { database in
            let statement = try database.prepare(
                TrackMetadataDatabaseQueries.fetchAll(trackIdsCount: trackIds.count)
            )

            for (index, trackId) in trackIds.enumerated() {
                try statement.bind(trackId, at: Int32(index + 1))
            }

            var result: [TrackMetadataDatabaseModel] = []
            result.reserveCapacity(trackIds.count)

            while try statement.step() == .row {
                result.append(try Self.map(statement.rowReader()))
            }

            return result
        }
    }

    /// Убирает повторяющиеся id, сохраняя порядок первого появления.
    private func orderedUniqueTrackIds(_ trackIds: [UUID]) -> [UUID] {
        var seenTrackIds = Set<UUID>()

        return trackIds.filter { trackId in
            seenTrackIds.insert(trackId).inserted
        }
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
        try statement.bind(model.label, at: 6)
        try statement.bind(model.genre, at: 7)
        try statement.bind(model.year, at: 8)
        try statement.bind(model.trackNumber, at: 9)
        try statement.bind(model.discNumber, at: 10)
        try statement.bind(model.bpm, at: 11)
        try statement.bind(model.keySignature, at: 12)
        try statement.bind(model.comment, at: 13)
        try statement.bind(model.duration, at: 14)
        try statement.bind(model.bitrate, at: 15)
        try statement.bind(model.sampleRate, at: 16)
        try statement.bind(model.channelCount, at: 17)
        try statement.bind(model.metadataUpdatedAt, at: 18)
    }

    private enum Constants {
        // SQLite по умолчанию ограничивает число bind-параметров, поэтому читаем metadata кусками.
        static let maxBoundIdsPerQuery = 500
    }
}
