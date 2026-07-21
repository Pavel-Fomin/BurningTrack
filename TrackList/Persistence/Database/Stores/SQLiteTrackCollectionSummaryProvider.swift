//
//  SQLiteTrackCollectionSummaryProvider.swift
//  TrackList
//
//  SQLite-реализация общей статистики музыкальных коллекций.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import Foundation

/// Получает агрегированную статистику коллекций одним SQLite-запросом вне главного потока.
final class SQLiteTrackCollectionSummaryProvider: TrackCollectionSummaryProviding, @unchecked Sendable {
    /// Сериализует доступ к единственному SQLite-соединению.
    private let executor: DatabaseExecutor

    init(executor: DatabaseExecutor) {
        self.executor = executor
    }

    convenience init(database: AppDatabase = .shared) throws {
        try self.init(executor: database.databaseExecutor())
    }

    /// Возвращает статистику только треков, непосредственно принадлежащих папке.
    func summaryForFolder(folderId: UUID) async throws -> TrackCollectionSummary {
        try await Task.detached(priority: .utility) { [self] in
            try makeSummary(
                sql: TrackCollectionSummaryDatabaseQueries.folder,
                collectionId: folderId
            )
        }.value
    }

    /// Возвращает статистику строк треклиста, сохраняя повторные вхождения одного трека.
    func summaryForTrackList(trackListId: UUID) async throws -> TrackCollectionSummary {
        try await Task.detached(priority: .utility) { [self] in
            try makeSummary(
                sql: TrackCollectionSummaryDatabaseQueries.trackList,
                collectionId: trackListId
            )
        }.value
    }

    /// Выполняет агрегирующий запрос и преобразует единственную строку результата в доменную модель.
    private func makeSummary(
        sql: String,
        collectionId: UUID
    ) throws -> TrackCollectionSummary {
        try executor.read { database in
            let statement = try database.prepare(sql)
            try statement.bind(collectionId, at: 1)

            guard try statement.step() == .row else {
                throw DatabaseError.sqliteFailed(message: "Агрегирующий запрос не вернул строку результата.")
            }

            let row = try statement.rowReader()
            return TrackCollectionSummary(
                trackCount: try row.requiredInt(at: 0),
                totalDuration: row.double(at: 1),
                totalFileSize: row.int64(at: 2),
                unknownDurationCount: try row.requiredInt(at: 3),
                unknownFileSizeCount: try row.requiredInt(at: 4)
            )
        }
    }
}
