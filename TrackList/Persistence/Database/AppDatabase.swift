//
//  AppDatabase.swift
//  TrackList
//
//  Единая точка владения SQLite-соединением приложения.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

// Открывает SQLite один раз за жизненный цикл приложения и запускает миграции.
final class AppDatabase {
    static let shared = AppDatabase(
        location: DatabaseLocation(),
        migrator: DatabaseMigrator(migrations: [
            .initialSchema,
            .initialTables,
            .trackListTracksAllowExternalTrackIds
        ])
    )

    private let location: DatabaseLocation
    private let migrator: DatabaseMigrator
    private let lock = NSLock()
    private var connection: DatabaseConnection?
    private var activeExecutor: DatabaseExecutor?

    private(set) var databaseURL: URL?

    init(location: DatabaseLocation, migrator: DatabaseMigrator) {
        self.location = location
        self.migrator = migrator
    }

    deinit {
        // Закрываем соединение при освобождении владельца, хотя singleton обычно живёт до завершения процесса.
        try? close()
    }

    func open() throws {
        lock.lock()
        defer {
            lock.unlock()
        }

        try openIfNeededLocked()
    }

    func databaseExecutor() throws -> DatabaseExecutor {
        lock.lock()
        defer {
            lock.unlock()
        }

        // Executor создаётся лениво после открытия базы и переиспользуется всеми Store.
        try openIfNeededLocked()

        guard let activeExecutor else {
            throw DatabaseError.databaseNotOpen
        }

        return activeExecutor
    }

    private func openIfNeededLocked() throws {
        // Повторные вызовы старта не создают второе соединение.
        guard connection == nil else { return }

        let url = try location.databaseURL()
        let openedConnection = try DatabaseConnection.open(url: url)

        do {
            try configure(openedConnection)
            try migrator.migrate(database: openedConnection)

            connection = openedConnection
            activeExecutor = DatabaseExecutor(connection: openedConnection)
            databaseURL = url
        } catch {
            try? openedConnection.close()
            throw error
        }
    }

    func close() throws {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard let connection else { return }

        // Закрываем именно сохранённое единственное соединение.
        try connection.close()

        self.connection = nil
        activeExecutor = nil
    }

    private func configure(_ database: DatabaseConnection) throws {
        // WAL разрешает чтение во время записи и лучше подходит для будущего постоянного хранилища UI-данных.
        try database.executeScript("PRAGMA journal_mode = WAL;")

        // foreign_keys включает контроль внешних ключей, потому что SQLite по умолчанию не применяет его автоматически.
        try database.executeScript("PRAGMA foreign_keys = ON;")

        // synchronous NORMAL снижает стоимость записи в WAL, сохраняя практичный уровень защиты от повреждения БД.
        try database.executeScript("PRAGMA synchronous = NORMAL;")

        // busy_timeout даёт SQLite время дождаться освобождения lock вместо мгновенной ошибки SQLITE_BUSY.
        let busyTimeoutMilliseconds: Int32 = 5_000
        try database.setBusyTimeout(milliseconds: busyTimeoutMilliseconds)
    }
}
