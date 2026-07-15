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
    case imported
    case purchasedITunes
}

// Режим повтора, сохранённый в player_state.
enum DatabaseRepeatMode: String, Equatable {
    case off
    case one
    case all
}

// Источник playback-контекста, сохранённый в player_state.
enum DatabasePlaybackContextType: String, Equatable {
    case playerQueue
    case trackList
    case libraryFolder
    case libraryRoot
    case libraryCollection
}

// Цветовая схема приложения в app_settings.
enum DatabasePreferredColorScheme: String, Equatable {
    case system
    case light
    case dark
}
