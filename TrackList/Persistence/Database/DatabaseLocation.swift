//
//  DatabaseLocation.swift
//  TrackList
//
//  Отвечает только за расположение файла SQLite-базы.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

// Возвращает URL файла базы данных без открытия SQLite и без выполнения SQL.
struct DatabaseLocation {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func databaseURL() throws -> URL {
        // Храним постоянную БД в Library/Application Support, чтобы не смешивать её с пользовательскими документами.
        guard let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw DatabaseError.applicationSupportDirectoryUnavailable
        }

        // Создаём Application Support при первом запуске, если iOS ещё не подготовила эту директорию.
        try fileManager.createDirectory(
            at: applicationSupportURL,
            withIntermediateDirectories: true
        )

        // Имя файла фиксируем отдельно от будущей схемы, чтобы миграции могли развивать содержимое без смены пути.
        return applicationSupportURL.appendingPathComponent("TrackList.sqlite")
    }
}
