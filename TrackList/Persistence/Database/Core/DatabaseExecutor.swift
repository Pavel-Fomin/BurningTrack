//
//  DatabaseExecutor.swift
//  TrackList
//
//  Единая точка выполнения SQL-операций и транзакций.
//
//  Created by Codex on 04.07.2026.
//

import Foundation

// Сериализует работу с одним SQLite-соединением и управляет транзакциями.
final class DatabaseExecutor {
    private let connection: DatabaseConnection
    private let lock = NSRecursiveLock()
    private var transactionDepth = 0

    init(connection: DatabaseConnection) {
        self.connection = connection
    }

    func read<T>(_ body: (DatabaseConnection) throws -> T) throws -> T {
        lock.lock()
        defer {
            lock.unlock()
        }

        // Чтения идут через тот же executor, чтобы не было параллельного доступа к одному handle.
        return try body(connection)
    }

    func write<T>(_ body: (DatabaseConnection) throws -> T) throws -> T {
        lock.lock()
        defer {
            lock.unlock()
        }

        // Одиночные записи используют autocommit SQLite; пакетные записи должны идти через transaction.
        return try body(connection)
    }

    func transaction<T>(_ body: (DatabaseConnection) throws -> T) throws -> T {
        lock.lock()
        defer {
            lock.unlock()
        }

        if transactionDepth > 0 {
            // Вложенные операции участвуют в уже открытой транзакции верхнего уровня.
            return try body(connection)
        }

        do {
            transactionDepth = 1
            try connection.executeScript("BEGIN IMMEDIATE TRANSACTION;")

            let result = try body(connection)

            try connection.executeScript("COMMIT;")
            transactionDepth = 0

            return result
        } catch {
            try? connection.executeScript("ROLLBACK;")
            transactionDepth = 0
            throw error
        }
    }
}

extension DatabaseExecutor {
    func fetchAll<T>(
        _ sql: String,
        map: (DatabaseRowReader) throws -> T
    ) throws -> [T] {
        try read { database in
            let statement = try database.prepare(sql)
            var result: [T] = []

            while try statement.step() == .row {
                result.append(try map(statement.rowReader()))
            }

            return result
        }
    }
}
