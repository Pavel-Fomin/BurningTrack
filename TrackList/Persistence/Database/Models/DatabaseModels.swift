//
//  DatabaseModels.swift
//  TrackList
//
//  Модели строк SQLite-таблиц.
//
//  Created by Codex on 04.07.2026.
//

import Foundation

// Строка таблицы folders.
struct FolderDatabaseModel: Equatable, Identifiable {
    let id: UUID
    var parentFolderId: UUID?
    var rootFolderId: UUID?
    var name: String
    var relativePath: String
    var bookmarkBase64: String?
    var isRoot: Bool
    var isAvailable: Bool
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int?
    var lastScannedAt: Date?
    var trackSortMode: String?
}

// Строка таблицы tracks.
struct TrackDatabaseModel: Equatable, Identifiable {
    let id: UUID
    var source: DatabaseTrackSource
    var folderId: UUID?
    var rootFolderId: UUID?
    var fileName: String
    var relativePath: String?
    var fileExtension: String?
    var fileSize: Int64?
    var fileDate: Date?
    var importedAt: Date
    var updatedAt: Date
    var bookmarkBase64: String?
    var assetURLString: String?
    var isAvailable: Bool
    var isDeleted: Bool
}

// Строка таблицы track_metadata.
struct TrackMetadataDatabaseModel: Equatable {
    let trackId: UUID
    var title: String?
    var artist: String?
    var album: String?
    var albumArtist: String?
    var label: String?
    var genre: String?
    var year: Int?
    var trackNumber: Int?
    var discNumber: Int?
    var bpm: Double?
    var keySignature: String?
    var comment: String?
    var duration: Double?
    var bitrate: Int?
    var sampleRate: Int?
    var channelCount: Int?
    var metadataUpdatedAt: Date
}

// Строка таблицы track_identity_keys.
struct TrackIdentityKeyDatabaseModel: Equatable, Identifiable {
    var id: String { identityKey }
    let identityKey: String
    var trackId: UUID
    var source: DatabaseTrackSource
    var createdAt: Date
    var updatedAt: Date
}

// Строка таблицы tracklists.
struct TrackListDatabaseModel: Equatable, Identifiable {
    let id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int?
    var isDeleted: Bool
}

// Строка таблицы tracklist_tracks.
struct TrackListTrackDatabaseModel: Equatable, Identifiable {
    let id: UUID
    var trackListId: UUID
    var trackId: UUID
    var position: Int
    var sourceSnapshot: DatabaseTrackSource
    var titleSnapshot: String?
    var artistSnapshot: String?
    var albumSnapshot: String?
    var durationSnapshot: Double?
    var fileNameSnapshot: String?
    var assetURLSnapshot: String?
    var isAvailableSnapshot: Bool
    var createdAt: Date
}

// Строка таблицы player_queue.
struct PlayerQueueItemDatabaseModel: Equatable, Identifiable {
    let id: UUID
    var trackId: UUID
    var position: Int
    var sourceSnapshot: DatabaseTrackSource
    var titleSnapshot: String?
    var artistSnapshot: String?
    var albumSnapshot: String?
    var durationSnapshot: Double?
    var fileNameSnapshot: String?
    var assetURLSnapshot: String?
    var isAvailableSnapshot: Bool
    var createdAt: Date
}

// Единственная строка таблицы player_state.
struct PlayerStateDatabaseModel: Equatable, Identifiable {
    let id: Int
    var currentQueueItemId: UUID?
    var currentTrackId: UUID?
    var playbackTime: Double
    var duration: Double?
    var isPlaying: Bool
    var repeatMode: DatabaseRepeatMode
    var shuffleEnabled: Bool
    var updatedAt: Date
}

// Единственная строка таблицы app_settings.
struct AppSettingsDatabaseModel: Equatable, Identifiable {
    let id: Int
    var schemaVersion: Int
    var preferredColorScheme: DatabasePreferredColorScheme
    var accentColorName: String?
    var lastOpenedTab: String?
    var isTagReadingEnabled: Bool
    var createdAt: Date
    var updatedAt: Date
}

// Единственная строка таблицы library_view_settings.
struct LibraryViewSettingsDatabaseModel: Equatable, Identifiable {
    let id: Int
    var sortMode: String
    var trackListsSortMode: String?
    var libraryFoldersSortMode: String?
    var groupMode: String
    var showTrackListBadges: Bool
    var showUnavailableTracks: Bool
    var showFileFormat: Bool
    var showPurchasedITunesSource: Bool
    var lastOpenedFolderId: UUID?
    var updatedAt: Date
}

// Единственная строка таблицы player_settings.
struct PlayerSettingsDatabaseModel: Equatable, Identifiable {
    let id: Int
    var autoPlayNext: Bool
    var restoreLastPosition: Bool
    var showMiniPlayer: Bool
    var backgroundPlaybackEnabled: Bool
    var updatedAt: Date
}
