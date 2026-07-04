//
//  DatabaseRowReader.swift
//  TrackList
//
//  Типобезопасное чтение текущей строки SQLite.
//
//  Created by Codex on 04.07.2026.
//

import Foundation
import SQLite3

// Читает значения из текущей строки prepared statement без раскрытия sqlite3_column_*.
struct DatabaseRowReader {
    private let statement: OpaquePointer

    init(statement: OpaquePointer) {
        self.statement = statement
    }

    func string(at index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let text = sqlite3_column_text(statement, index) else {
            return nil
        }

        return String(cString: text)
    }

    func requiredString(at index: Int32) throws -> String {
        guard let value = string(at: index) else {
            throw DatabaseError.missingRequiredColumn(name: columnName(at: index))
        }

        return value
    }

    func int(at index: Int32) -> Int? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }

        return Int(sqlite3_column_int64(statement, index))
    }

    func requiredInt(at index: Int32) throws -> Int {
        guard let value = int(at: index) else {
            throw DatabaseError.missingRequiredColumn(name: columnName(at: index))
        }

        return value
    }

    func int64(at index: Int32) -> Int64? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }

        return sqlite3_column_int64(statement, index)
    }

    func double(at index: Int32) -> Double? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }

        return sqlite3_column_double(statement, index)
    }

    func requiredDouble(at index: Int32) throws -> Double {
        guard let value = double(at: index) else {
            throw DatabaseError.missingRequiredColumn(name: columnName(at: index))
        }

        return value
    }

    func bool(at index: Int32) -> Bool? {
        guard let value = int(at: index) else {
            return nil
        }

        return DatabaseValueCodec.decodeBool(value)
    }

    func requiredBool(at index: Int32) throws -> Bool {
        guard let value = bool(at: index) else {
            throw DatabaseError.missingRequiredColumn(name: columnName(at: index))
        }

        return value
    }

    func uuid(at index: Int32) throws -> UUID? {
        guard let value = string(at: index) else {
            return nil
        }

        guard let uuid = DatabaseValueCodec.decodeUUID(value) else {
            throw DatabaseError.invalidColumnValue(column: columnName(at: index), value: value)
        }

        return uuid
    }

    func requiredUUID(at index: Int32) throws -> UUID {
        guard let value = try uuid(at: index) else {
            throw DatabaseError.missingRequiredColumn(name: columnName(at: index))
        }

        return value
    }

    func date(at index: Int32) throws -> Date? {
        guard let value = string(at: index) else {
            return nil
        }

        guard let date = DatabaseDateCodec.decode(value) else {
            throw DatabaseError.invalidColumnValue(column: columnName(at: index), value: value)
        }

        return date
    }

    func requiredDate(at index: Int32) throws -> Date {
        guard let value = try date(at: index) else {
            throw DatabaseError.missingRequiredColumn(name: columnName(at: index))
        }

        return value
    }

    private func columnName(at index: Int32) -> String {
        guard let name = sqlite3_column_name(statement, index) else {
            return "column_\(index)"
        }

        return String(cString: name)
    }
}
