//
//  DatabaseStatement.swift
//  TrackList
//
//  Обёртка над prepared statement SQLite.
//
//  Created by Codex on 04.07.2026.
//

import Foundation
import SQLite3

// Представляет результат одного шага выполнения prepared statement.
enum DatabaseStepResult {
    case row
    case done
}

// Инкапсулирует bind, step и finalize для одного SQL-запроса.
final class DatabaseStatement {
    private let connection: DatabaseConnection
    private var statement: OpaquePointer?

    init(connection: DatabaseConnection, sql: String) throws {
        self.connection = connection

        var preparedStatement: OpaquePointer?
        let result = try connection.withRawDatabase { database in
            sqlite3_prepare_v2(database, sql, -1, &preparedStatement, nil)
        }

        guard result == SQLITE_OK, let preparedStatement else {
            throw DatabaseError.sqliteFailed(message: connection.errorMessage)
        }

        statement = preparedStatement
    }

    deinit {
        // finalize обязателен для освобождения sqlite3_stmt и связанных ресурсов.
        sqlite3_finalize(statement)
    }

    func bind(_ value: String?, at index: Int32) throws {
        guard let value else {
            try bindNull(at: index)
            return
        }

        let destructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        guard sqlite3_bind_text(try rawStatement(), index, value, -1, destructor) == SQLITE_OK else {
            throw DatabaseError.sqliteFailed(message: connection.errorMessage)
        }
    }

    func bind(_ value: Int?, at index: Int32) throws {
        guard let value else {
            try bindNull(at: index)
            return
        }

        try bind(Int64(value), at: index)
    }

    func bind(_ value: Int64?, at index: Int32) throws {
        guard let value else {
            try bindNull(at: index)
            return
        }

        guard sqlite3_bind_int64(try rawStatement(), index, value) == SQLITE_OK else {
            throw DatabaseError.sqliteFailed(message: connection.errorMessage)
        }
    }

    func bind(_ value: Double?, at index: Int32) throws {
        guard let value else {
            try bindNull(at: index)
            return
        }

        guard sqlite3_bind_double(try rawStatement(), index, value) == SQLITE_OK else {
            throw DatabaseError.sqliteFailed(message: connection.errorMessage)
        }
    }

    func bind(_ value: Bool?, at index: Int32) throws {
        guard let value else {
            try bindNull(at: index)
            return
        }

        try bind(DatabaseValueCodec.encode(value), at: index)
    }

    func bind(_ value: UUID?, at index: Int32) throws {
        guard let value else {
            try bindNull(at: index)
            return
        }

        try bind(DatabaseValueCodec.encode(value), at: index)
    }

    func bind(_ value: Date?, at index: Int32) throws {
        guard let value else {
            try bindNull(at: index)
            return
        }

        try bind(DatabaseDateCodec.encode(value), at: index)
    }

    func execute() throws {
        // Команды insert/update/delete должны завершаться SQLITE_DONE.
        guard try step() == .done else {
            throw DatabaseError.sqliteFailed(message: "SQL-запрос вернул строку там, где ожидалось завершение.")
        }
    }

    func step() throws -> DatabaseStepResult {
        let result = sqlite3_step(try rawStatement())

        switch result {
        case SQLITE_ROW:
            return .row
        case SQLITE_DONE:
            return .done
        default:
            throw DatabaseError.sqliteFailed(message: connection.errorMessage)
        }
    }

    func rowReader() throws -> DatabaseRowReader {
        // Reader живёт только до следующего step текущего statement.
        DatabaseRowReader(statement: try rawStatement())
    }

    private func bindNull(at index: Int32) throws {
        guard sqlite3_bind_null(try rawStatement(), index) == SQLITE_OK else {
            throw DatabaseError.sqliteFailed(message: connection.errorMessage)
        }
    }

    private func rawStatement() throws -> OpaquePointer {
        guard let statement else {
            throw DatabaseError.sqliteFailed(message: "SQLite statement уже освобождён.")
        }

        return statement
    }
}
