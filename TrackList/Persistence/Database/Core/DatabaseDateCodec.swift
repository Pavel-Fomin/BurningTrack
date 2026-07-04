//
//  DatabaseDateCodec.swift
//  TrackList
//
//  Единый кодек дат для SQLite-строк.
//
//  Created by Codex on 04.07.2026.
//

import Foundation

// Преобразует Date в текстовый формат, который используется всеми таблицами базы.
enum DatabaseDateCodec {
    static func encode(_ date: Date) -> String {
        // Создаём formatter на вызов, чтобы не разделять изменяемый formatter между потоками.
        ISO8601DateFormatter().string(from: date)
    }

    static func decode(_ value: String) -> Date? {
        // Все даты в SQLite хранятся как ISO8601 TEXT, чтобы схема оставалась читаемой.
        ISO8601DateFormatter().date(from: value)
    }
}
