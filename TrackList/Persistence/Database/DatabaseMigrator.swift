//
//  DatabaseMigrator.swift
//  TrackList
//
//  Выполняет зарегистрированные миграции SQLite-схемы.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

// Отвечает за служебную таблицу миграций и последовательное применение новых миграций.
final class DatabaseMigrator {
    private let migrations: [DatabaseMigration]
    private let dateFormatter: ISO8601DateFormatter

    init(migrations: [DatabaseMigration]) {
        self.migrations = migrations
        self.dateFormatter = ISO8601DateFormatter()
    }

    func migrate(database: DatabaseConnection) throws {
        // Служебная таблица создаётся мигратором до выполнения списка миграций.
        try ensureSchemaMigrationsTable(database: database)

        let appliedMigrationIdentifiers = try loadAppliedMigrationIdentifiers(database: database)

        for migration in migrations where appliedMigrationIdentifiers.contains(migration.identifier) == false {
            try apply(migration, database: database)
        }
    }

    private func ensureSchemaMigrationsTable(database: DatabaseConnection) throws {
        try database.executeScript(
            """
            CREATE TABLE IF NOT EXISTS schema_migrations (
                identifier TEXT PRIMARY KEY NOT NULL,
                applied_at TEXT NOT NULL
            );
            """,
        )
    }

    private func loadAppliedMigrationIdentifiers(database: DatabaseConnection) throws -> Set<String> {
        let sql = "SELECT identifier FROM schema_migrations;"
        let statement = try database.prepare(sql)

        var identifiers = Set<String>()

        while try statement.step() == .row {
            let identifier = try statement.rowReader().requiredString(at: 0)
            identifiers.insert(identifier)
        }

        return identifiers
    }

    private func apply(_ migration: DatabaseMigration, database: DatabaseConnection) throws {
        do {
            // Каждая миграция применяется атомарно вместе с записью в schema_migrations.
            let executor = DatabaseExecutor(connection: database)
            try executor.transaction { transaction in
                try migration.migrate(transaction)
                try recordAppliedMigration(migration, database: transaction)
            }
        } catch {
            throw DatabaseError.migrationFailed(identifier: migration.identifier, underlying: error)
        }
    }

    private func recordAppliedMigration(
        _ migration: DatabaseMigration,
        database: DatabaseConnection
    ) throws {
        let sql = "INSERT INTO schema_migrations (identifier, applied_at) VALUES (?, ?);"
        let statement = try database.prepare(sql)

        let appliedAt = dateFormatter.string(from: Date())

        // Записываем идентификатор и дату через bind, чтобы служебные значения не интерполировались в SQL.
        try statement.bind(migration.identifier, at: 1)
        try statement.bind(appliedAt, at: 2)
        try statement.execute()
    }
}
