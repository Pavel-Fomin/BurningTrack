//
//  DatabaseValueCodec.swift
//  TrackList
//
//  Единые преобразования Swift-значений в SQLite-совместимые значения.
//
//  Created by Codex on 04.07.2026.
//

import Foundation

// Хранит правила сериализации скалярных значений, общие для всех Store.
enum DatabaseValueCodec {
    static func encode(_ value: UUID) -> String {
        // UUID хранится как TEXT, чтобы его можно было читать без бинарного декодирования.
        value.uuidString
    }

    static func decodeUUID(_ value: String) -> UUID? {
        // Невалидный UUID считается повреждением строки и обрабатывается вызывающим кодом.
        UUID(uuidString: value)
    }

    static func encode(_ value: Bool) -> Int {
        // SQLite не имеет отдельного Bool-типа, поэтому используем INTEGER 0/1.
        value ? 1 : 0
    }

    static func decodeBool(_ value: Int) -> Bool {
        // Любое ненулевое значение читается как true, но CHECK-ограничения схемы держат 0/1.
        value != 0
    }
}
