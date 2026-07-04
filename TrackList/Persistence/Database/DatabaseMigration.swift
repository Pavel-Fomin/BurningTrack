//
//  DatabaseMigration.swift
//  TrackList
//
//  Описывает отдельную миграцию SQLite-схемы.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import SQLite3

// Хранит идентификатор миграции и действие, которое изменяет схему базы.
struct DatabaseMigration {
    let identifier: String
    let migrate: (OpaquePointer) throws -> Void
}

extension DatabaseMigration {
    // Первая миграция фиксирует стартовую версию схемы без создания бизнес-таблиц.
    static let initialSchema = DatabaseMigration(identifier: "001_initial_schema") { _ in
        // Бизнес-таблицы треков, плеера и треклистов появятся в следующих фазах.
    }
}
