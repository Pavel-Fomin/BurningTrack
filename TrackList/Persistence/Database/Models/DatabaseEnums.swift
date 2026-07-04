//
//  DatabaseEnums.swift
//  TrackList
//
//  Перечисления значений, которые хранятся в SQLite.
//
//  Created by Codex on 04.07.2026.
//

import Foundation

// Источник трека в таблицах базы, отделённый от runtime-моделей приложения.
enum DatabaseTrackSource: String, Equatable {
    case library
    case purchasedITunes
}

// Режим повтора, сохранённый в player_state.
enum DatabaseRepeatMode: String, Equatable {
    case off
    case one
    case all
}

// Цветовая схема приложения в app_settings.
enum DatabasePreferredColorScheme: String, Equatable {
    case system
    case light
    case dark
}

// Способ обработки дубликатов при экспорте.
enum DatabaseExportDuplicateHandling: String, Equatable {
    case keepBoth
    case skip
    case replace
}
