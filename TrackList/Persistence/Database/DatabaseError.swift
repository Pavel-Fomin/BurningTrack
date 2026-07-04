//
//  DatabaseError.swift
//  TrackList
//
//  Единые ошибки инфраструктуры SQLite.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

// Описывает технические ошибки постоянного SQLite-хранилища.
enum DatabaseError: Error, LocalizedError {
    case applicationSupportDirectoryUnavailable
    case databaseNotOpen
    case openFailed(message: String)
    case closeFailed(message: String)
    case sqliteFailed(message: String)
    case migrationFailed(identifier: String, underlying: Error)
    case missingRequiredColumn(name: String)
    case invalidColumnValue(column: String, value: String)

    var errorDescription: String? {
        switch self {
        case .applicationSupportDirectoryUnavailable:
            return "Не удалось получить директорию Application Support."
        case .databaseNotOpen:
            return "SQLite-база не открыта."
        case .openFailed(let message):
            return "Не удалось открыть SQLite-базу: \(message)"
        case .closeFailed(let message):
            return "Не удалось закрыть SQLite-соединение: \(message)"
        case .sqliteFailed(let message):
            return "Ошибка SQLite: \(message)"
        case .migrationFailed(let identifier, let underlying):
            return "Не удалось выполнить миграцию \(identifier): \(underlying.localizedDescription)"
        case .missingRequiredColumn(let name):
            return "В SQLite-строке отсутствует обязательная колонка \(name)."
        case .invalidColumnValue(let column, let value):
            return "Некорректное значение SQLite-колонки \(column): \(value)"
        }
    }
}
