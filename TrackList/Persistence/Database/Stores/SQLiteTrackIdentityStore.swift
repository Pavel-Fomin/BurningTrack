//
//  SQLiteTrackIdentityStore.swift
//  TrackList
//
//  Доступ к таблице стабильных identity-ключей треков.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

// SQLite-реализация доступа только к таблице track_identity_keys.
final class SQLiteTrackIdentityStore {
    private let executor: DatabaseExecutor

    init(executor: DatabaseExecutor) {
        self.executor = executor
    }

    convenience init(database: AppDatabase = .shared) throws {
        try self.init(executor: database.databaseExecutor())
    }

    func fetch(identityKey: String) throws -> TrackIdentityKeyDatabaseModel? {
        try executor.read { database in
            let statement = try database.prepare(TrackIdentityKeyDatabaseQueries.fetch)
            try statement.bind(identityKey, at: 1)

            guard try statement.step() == .row else {
                return nil
            }

            return try Self.map(statement.rowReader())
        }
    }

    func upsert(_ model: TrackIdentityKeyDatabaseModel) throws {
        try executor.write { database in
            let statement = try database.prepare(TrackIdentityKeyDatabaseQueries.upsert)
            try Self.bindInsert(model, statement: statement)
            try statement.execute()
        }
    }

    func deleteAll(trackId: UUID) throws {
        try executor.write { database in
            let statement = try database.prepare(TrackIdentityKeyDatabaseQueries.deleteAllForTrack)
            try statement.bind(trackId, at: 1)
            try statement.execute()
        }
    }

    private static func map(_ row: DatabaseRowReader) throws -> TrackIdentityKeyDatabaseModel {
        let sourceRawValue = try row.requiredString(at: 2)
        guard let source = DatabaseTrackSource(rawValue: sourceRawValue) else {
            throw DatabaseError.invalidColumnValue(column: DatabaseSchema.TrackIdentityKeys.source, value: sourceRawValue)
        }

        return TrackIdentityKeyDatabaseModel(
            identityKey: try row.requiredString(at: 0),
            trackId: try row.requiredUUID(at: 1),
            source: source,
            createdAt: try row.requiredDate(at: 3),
            updatedAt: try row.requiredDate(at: 4)
        )
    }

    private static func bindInsert(
        _ model: TrackIdentityKeyDatabaseModel,
        statement: DatabaseStatement
    ) throws {
        // Порядок bind соответствует INSERT/UPSERT-запросу track_identity_keys.
        try statement.bind(model.identityKey, at: 1)
        try statement.bind(model.trackId, at: 2)
        try statement.bind(model.source.rawValue, at: 3)
        try statement.bind(model.createdAt, at: 4)
        try statement.bind(model.updatedAt, at: 5)
    }
}

// Фасад identity-слоя создаёт imported track и его identity key в одной транзакции.
final class TrackIdentityDatabaseStore {
    private let executor: DatabaseExecutor
    private let trackStore: SQLiteTrackStore
    private let identityStore: SQLiteTrackIdentityStore

    init(executor: DatabaseExecutor) {
        self.executor = executor
        self.trackStore = SQLiteTrackStore(executor: executor)
        self.identityStore = SQLiteTrackIdentityStore(executor: executor)
    }

    convenience init(database: AppDatabase = .shared) throws {
        try self.init(executor: database.databaseExecutor())
    }

    /// Возвращает существующий trackId для imported identity или создаёт новую SQLite-запись.
    func trackIdForImportedIdentity(
        identityKey: String,
        fileURL: URL
    ) throws -> UUID {
        if let existing = try identityStore.fetch(identityKey: identityKey) {
            return existing.trackId
        }

        let trackId = UUID()
        try bindImportedTrack(
            id: trackId,
            identityKey: identityKey,
            fileURL: fileURL
        )
        return trackId
    }

    /// Привязывает imported identity к trackId и создаёт строку tracks, если её ещё нет.
    func bindImportedTrack(
        id trackId: UUID,
        identityKey: String,
        fileURL: URL
    ) throws {
        let now = Date()

        try executor.transaction { _ in
            let existingTrack = try trackStore.fetch(id: trackId)
            let model = TrackDatabaseModel(
                id: trackId,
                source: .imported,
                folderId: nil,
                rootFolderId: nil,
                fileName: fileURL.lastPathComponent,
                relativePath: nil,
                fileExtension: fileURL.pathExtension.lowercased(),
                fileSize: existingTrack?.fileSize,
                fileDate: fileDate(for: fileURL) ?? existingTrack?.fileDate ?? now,
                importedAt: existingTrack?.importedAt ?? now,
                updatedAt: now,
                bookmarkBase64: existingTrack?.bookmarkBase64,
                assetURLString: fileURL.standardizedFileURL.absoluteString,
                isAvailable: FileManager.default.fileExists(atPath: fileURL.path),
                isDeleted: false
            )
            try trackStore.upsert(model)

            let existingIdentity = try identityStore.fetch(identityKey: identityKey)
            let identity = TrackIdentityKeyDatabaseModel(
                identityKey: identityKey,
                trackId: trackId,
                source: .imported,
                createdAt: existingIdentity?.createdAt ?? now,
                updatedAt: now
            )
            try identityStore.upsert(identity)
        }
    }

    /// Атомарно заменяет все старые imported identity-ключи трека на новый путь файла.
    func replaceImportedTrackIdentity(
        id trackId: UUID,
        identityKey: String,
        fileURL: URL
    ) throws {
        try executor.transaction { _ in
            try identityStore.deleteAll(trackId: trackId)
            try bindImportedTrack(
                id: trackId,
                identityKey: identityKey,
                fileURL: fileURL
            )
        }
    }

    /// Удаляет все imported identity-ключи указанного trackId.
    func forgetTrack(id trackId: UUID) throws {
        try identityStore.deleteAll(trackId: trackId)
    }

    func identity(identityKey: String) throws -> TrackIdentityKeyDatabaseModel? {
        try identityStore.fetch(identityKey: identityKey)
    }

    private func fileDate(for url: URL) -> Date? {
        let values = try? url.resourceValues(
            forKeys: [
                .contentModificationDateKey,
                .creationDateKey
            ]
        )

        return values?.contentModificationDate ?? values?.creationDate
    }
}
