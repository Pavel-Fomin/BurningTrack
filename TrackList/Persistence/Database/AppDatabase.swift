//
//  AppDatabase.swift
//  TrackList
//
//  Единая точка владения SQLite-соединением приложения.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation
import SQLite3

// Открывает SQLite один раз за жизненный цикл приложения и запускает миграции.
final class AppDatabase {
    static let shared = AppDatabase(
        location: DatabaseLocation(),
        migrator: DatabaseMigrator(migrations: [
            .initialSchema,
            .initialTables
        ])
    )

    private let location: DatabaseLocation
    private let migrator: DatabaseMigrator
    private let lock = NSLock()
    private var connection: OpaquePointer?

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

        // Повторные вызовы старта не создают второе соединение.
        guard connection == nil else { return }

        let url = try location.databaseURL()
        var openedConnection: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX

        // sqlite3_open_v2 создаёт файл базы при первом запуске и открывает единственное приложениевое соединение.
        let openResult = sqlite3_open_v2(url.path, &openedConnection, flags, nil)

        guard openResult == SQLITE_OK, let openedConnection else {
            let message = openedConnection.map { sqliteErrorMessage($0) } ?? "SQLite не вернул соединение."
            if let openedConnection {
                sqlite3_close(openedConnection)
            }
            throw DatabaseError.openFailed(message: message)
        }

        do {
            try configure(openedConnection)
            try migrator.migrate(database: openedConnection)

            connection = openedConnection
            databaseURL = url
        } catch {
            sqlite3_close(openedConnection)
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
        let closeResult = sqlite3_close(connection)

        guard closeResult == SQLITE_OK else {
            throw DatabaseError.closeFailed(message: sqliteErrorMessage(connection))
        }

        self.connection = nil
    }

    private func configure(_ database: OpaquePointer) throws {
        // WAL разрешает чтение во время записи и лучше подходит для будущего постоянного хранилища UI-данных.
        try execute("PRAGMA journal_mode = WAL;", database: database)

        // foreign_keys включает контроль внешних ключей, потому что SQLite по умолчанию не применяет его автоматически.
        try execute("PRAGMA foreign_keys = ON;", database: database)

        // synchronous NORMAL снижает стоимость записи в WAL, сохраняя практичный уровень защиты от повреждения БД.
        try execute("PRAGMA synchronous = NORMAL;", database: database)

        // busy_timeout даёт SQLite время дождаться освобождения lock вместо мгновенной ошибки SQLITE_BUSY.
        let busyTimeoutMilliseconds: Int32 = 5_000
        guard sqlite3_busy_timeout(database, busyTimeoutMilliseconds) == SQLITE_OK else {
            throw DatabaseError.sqliteFailed(message: sqliteErrorMessage(database))
        }
    }

    private func execute(_ sql: String, database: OpaquePointer) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?

        // sqlite3_exec используется только для служебных PRAGMA-команд без результирующей обработки.
        let result = sqlite3_exec(database, sql, nil, nil, &errorMessage)

        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? sqliteErrorMessage(database)
            sqlite3_free(errorMessage)
            throw DatabaseError.sqliteFailed(message: message)
        }
    }

    private func sqliteErrorMessage(_ database: OpaquePointer) -> String {
        // Берём сообщение ошибки из текущего соединения SQLite.
        String(cString: sqlite3_errmsg(database))
    }
}
