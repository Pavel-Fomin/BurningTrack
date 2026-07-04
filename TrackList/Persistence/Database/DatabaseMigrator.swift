//
//  DatabaseMigrator.swift
//  TrackList
//
//  Выполняет зарегистрированные миграции SQLite-схемы.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation
import SQLite3

// Отвечает за служебную таблицу миграций и последовательное применение новых миграций.
final class DatabaseMigrator {
    private let migrations: [DatabaseMigration]
    private let dateFormatter: ISO8601DateFormatter

    init(migrations: [DatabaseMigration]) {
        self.migrations = migrations
        self.dateFormatter = ISO8601DateFormatter()
    }

    func migrate(database: OpaquePointer) throws {
        // Служебная таблица создаётся мигратором до выполнения списка миграций.
        try ensureSchemaMigrationsTable(database: database)

        let appliedMigrationIdentifiers = try loadAppliedMigrationIdentifiers(database: database)

        for migration in migrations where appliedMigrationIdentifiers.contains(migration.identifier) == false {
            try apply(migration, database: database)
        }
    }

    private func ensureSchemaMigrationsTable(database: OpaquePointer) throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS schema_migrations (
                identifier TEXT PRIMARY KEY NOT NULL,
                applied_at TEXT NOT NULL
            );
            """,
            database: database
        )
    }

    private func loadAppliedMigrationIdentifiers(database: OpaquePointer) throws -> Set<String> {
        let sql = "SELECT identifier FROM schema_migrations;"
        var statement: OpaquePointer?

        // Читаем уже применённые миграции через prepared statement, чтобы не зависеть от формата SQL-строк.
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.sqliteFailed(message: sqliteErrorMessage(database))
        }

        defer {
            sqlite3_finalize(statement)
        }

        var identifiers = Set<String>()

        var stepResult = sqlite3_step(statement)

        while stepResult == SQLITE_ROW {
            guard let text = sqlite3_column_text(statement, 0) else { continue }
            let identifier = String(
                cString: UnsafeRawPointer(text).assumingMemoryBound(to: CChar.self)
            )
            identifiers.insert(identifier)
            stepResult = sqlite3_step(statement)
        }

        guard stepResult == SQLITE_DONE else {
            throw DatabaseError.sqliteFailed(message: sqliteErrorMessage(database))
        }

        return identifiers
    }

    private func apply(_ migration: DatabaseMigration, database: OpaquePointer) throws {
        do {
            // Каждая миграция применяется атомарно вместе с записью в schema_migrations.
            try execute("BEGIN IMMEDIATE TRANSACTION;", database: database)
            try migration.migrate(database)
            try recordAppliedMigration(migration, database: database)
            try execute("COMMIT;", database: database)
        } catch {
            try? execute("ROLLBACK;", database: database)
            throw DatabaseError.migrationFailed(identifier: migration.identifier, underlying: error)
        }
    }

    private func recordAppliedMigration(
        _ migration: DatabaseMigration,
        database: OpaquePointer
    ) throws {
        let sql = "INSERT INTO schema_migrations (identifier, applied_at) VALUES (?, ?);"
        var statement: OpaquePointer?

        // Записываем идентификатор и дату через bind, чтобы служебные значения не интерполировались в SQL.
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.sqliteFailed(message: sqliteErrorMessage(database))
        }

        defer {
            sqlite3_finalize(statement)
        }

        let appliedAt = dateFormatter.string(from: Date())
        let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        guard sqlite3_bind_text(statement, 1, migration.identifier, -1, transientDestructor) == SQLITE_OK else {
            throw DatabaseError.sqliteFailed(message: sqliteErrorMessage(database))
        }

        guard sqlite3_bind_text(statement, 2, appliedAt, -1, transientDestructor) == SQLITE_OK else {
            throw DatabaseError.sqliteFailed(message: sqliteErrorMessage(database))
        }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.sqliteFailed(message: sqliteErrorMessage(database))
        }
    }

    private func execute(_ sql: String, database: OpaquePointer) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?

        // sqlite3_exec подходит для служебных DDL/transaction-команд, где не нужны результирующие строки.
        let result = sqlite3_exec(database, sql, nil, nil, &errorMessage)

        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? sqliteErrorMessage(database)
            sqlite3_free(errorMessage)
            throw DatabaseError.sqliteFailed(message: message)
        }
    }

    private func sqliteErrorMessage(_ database: OpaquePointer) -> String {
        // sqlite3_errmsg возвращает диагностический текст последней ошибки текущего соединения.
        String(cString: sqlite3_errmsg(database))
    }
}
