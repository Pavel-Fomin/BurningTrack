//
//  DatabaseConnection.swift
//  TrackList
//
//  Низкоуровневый владелец SQLite-соединения.
//
//  Created by Codex on 04.07.2026.
//

import Foundation
import SQLite3

// Оборачивает OpaquePointer и скрывает SQLite C API от остальных слоёв приложения.
final class DatabaseConnection {
    private var database: OpaquePointer?

    private init(database: OpaquePointer) {
        self.database = database
    }

    deinit {
        // Страховочное закрытие нужно для тестовых баз и раннего освобождения AppDatabase.
        try? close()
    }

    static func open(url: URL) throws -> DatabaseConnection {
        var openedConnection: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX

        // sqlite3_open_v2 создаёт файл базы при первом запуске и открывает потокобезопасное соединение.
        let result = sqlite3_open_v2(url.path, &openedConnection, flags, nil)

        guard result == SQLITE_OK, let openedConnection else {
            let message = openedConnection.map { String(cString: sqlite3_errmsg($0)) }
                ?? "SQLite не вернул соединение."
            if let openedConnection {
                sqlite3_close(openedConnection)
            }
            throw DatabaseError.openFailed(message: message)
        }

        return DatabaseConnection(database: openedConnection)
    }

    func close() throws {
        guard let database else { return }

        // Закрытие выполняется только один раз для текущего SQLite handle.
        let result = sqlite3_close(database)

        guard result == SQLITE_OK else {
            throw DatabaseError.closeFailed(message: errorMessage)
        }

        self.database = nil
    }

    func setBusyTimeout(milliseconds: Int32) throws {
        // busy_timeout даёт SQLite время дождаться освобождения lock вместо SQLITE_BUSY.
        guard sqlite3_busy_timeout(try rawDatabase(), milliseconds) == SQLITE_OK else {
            throw DatabaseError.sqliteFailed(message: errorMessage)
        }
    }

    func executeScript(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?

        // sqlite3_exec используется только в Core для DDL, PRAGMA и transaction-команд.
        let result = sqlite3_exec(try rawDatabase(), sql, nil, nil, &errorMessage)

        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? self.errorMessage
            sqlite3_free(errorMessage)
            throw DatabaseError.sqliteFailed(message: message)
        }
    }

    func prepare(_ sql: String) throws -> DatabaseStatement {
        // Statement создаётся через отдельную обёртку, чтобы Store не работали с sqlite3_stmt напрямую.
        try DatabaseStatement(connection: self, sql: sql)
    }

    fileprivate func rawDatabase() throws -> OpaquePointer {
        guard let database else {
            throw DatabaseError.databaseNotOpen
        }

        return database
    }

    var errorMessage: String {
        guard let database else {
            return "SQLite-соединение закрыто."
        }

        // sqlite3_errmsg возвращает диагностический текст последней ошибки текущего соединения.
        return String(cString: sqlite3_errmsg(database))
    }
}

extension DatabaseConnection {
    // Даёт Core-объектам доступ к handle без раскрытия sqlite3_* на верхние слои.
    func withRawDatabase<T>(_ body: (OpaquePointer) throws -> T) throws -> T {
        try body(rawDatabase())
    }
}
