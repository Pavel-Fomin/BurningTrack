//
//  DatabaseDiagnosticsStore.swift
//  TrackList
//
//  DEBUG-хранилище агрегированного состояния SQLite-фонотеки.
//
//  Created by Pavel Fomin on 04.07.2026.
//

#if DEBUG

import Foundation

// Снимок фактического состояния SQLite-фонотеки после завершённой операции.
struct DatabaseDiagnosticsSnapshot {
    let rootFoldersCount: Int
    let foldersTotalCount: Int
    let libraryTracksTotalCount: Int
    let metadataRowsCount: Int
    let unavailableFoldersCount: Int
    let unavailableTracksCount: Int
    let rootFolders: [DatabaseDiagnosticsRootFolderSnapshot]
}

// Агрегаты по одному корневому разделу фонотеки.
struct DatabaseDiagnosticsRootFolderSnapshot {
    let name: String
    let tracksCount: Int
    let foldersCount: Int
}

// Читает только диагностические агрегаты и не участвует в production-поведении приложения.
final class DatabaseDiagnosticsStore {
    private let executor: DatabaseExecutor

    init(executor: DatabaseExecutor) {
        self.executor = executor
    }

    convenience init(database: AppDatabase = .shared) throws {
        try self.init(executor: database.databaseExecutor())
    }

    /// Возвращает фактические счётчики таблиц фонотеки на момент чтения.
    func librarySnapshot() throws -> DatabaseDiagnosticsSnapshot {
        try executor.read { database in
            DatabaseDiagnosticsSnapshot(
                rootFoldersCount: try count(database, sql: Self.rootFoldersCountSQL),
                foldersTotalCount: try count(database, sql: Self.foldersTotalCountSQL),
                libraryTracksTotalCount: try count(database, sql: Self.libraryTracksTotalCountSQL),
                metadataRowsCount: try count(database, sql: Self.metadataRowsCountSQL),
                unavailableFoldersCount: try count(database, sql: Self.unavailableFoldersCountSQL),
                unavailableTracksCount: try count(database, sql: Self.unavailableTracksCountSQL),
                rootFolders: try rootFolderSnapshots(database)
            )
        }
    }

    /// Выполняет COUNT-запрос, чтобы лог отражал состояние БД, а не результат последней операции.
    private func count(
        _ database: DatabaseConnection,
        sql: String
    ) throws -> Int {
        let statement = try database.prepare(sql)

        guard try statement.step() == .row else {
            throw DatabaseError.sqliteFailed(message: "Диагностический COUNT-запрос не вернул строку.")
        }

        return try statement.rowReader().requiredInt(at: 0)
    }

    /// Группирует активные library-треки и все папки по корневому разделу.
    private func rootFolderSnapshots(
        _ database: DatabaseConnection
    ) throws -> [DatabaseDiagnosticsRootFolderSnapshot] {
        let statement = try database.prepare(Self.rootFolderSnapshotsSQL)
        var result: [DatabaseDiagnosticsRootFolderSnapshot] = []

        while try statement.step() == .row {
            let row = try statement.rowReader()
            result.append(
                DatabaseDiagnosticsRootFolderSnapshot(
                    name: try row.requiredString(at: 0),
                    tracksCount: try row.requiredInt(at: 1),
                    foldersCount: try row.requiredInt(at: 2)
                )
            )
        }

        return result
    }

    // SQL намеренно локален для DEBUG-диагностики и не расширяет production-запросы.
    private static let rootFoldersCountSQL = """
    SELECT COUNT(*)
    FROM folders
    WHERE is_root = 1;
    """

    private static let foldersTotalCountSQL = """
    SELECT COUNT(*)
    FROM folders;
    """

    private static let libraryTracksTotalCountSQL = """
    SELECT COUNT(*)
    FROM tracks
    WHERE source = 'library' AND is_deleted = 0;
    """

    private static let metadataRowsCountSQL = """
    SELECT COUNT(*)
    FROM track_metadata;
    """

    private static let unavailableFoldersCountSQL = """
    SELECT COUNT(*)
    FROM folders
    WHERE is_available = 0;
    """

    private static let unavailableTracksCountSQL = """
    SELECT COUNT(*)
    FROM tracks
    WHERE source = 'library' AND is_deleted = 0 AND is_available = 0;
    """

    private static let rootFolderSnapshotsSQL = """
    SELECT
        root.name,
        (
            SELECT COUNT(*)
            FROM tracks AS track
            WHERE track.root_folder_id = root.id
              AND track.source = 'library'
              AND track.is_deleted = 0
        ) AS tracks_count,
        (
            SELECT COUNT(*)
            FROM folders AS folder
            WHERE folder.id = root.id OR folder.root_folder_id = root.id
        ) AS folders_count
    FROM folders AS root
    WHERE root.is_root = 1
    ORDER BY root.name COLLATE NOCASE ASC;
    """
}

#endif
