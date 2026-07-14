//
//  DatabaseSchema.swift
//  TrackList
//
//  Имена таблиц и колонок SQLite-схемы.
//
//  Created by Codex on 04.07.2026.
//

import Foundation

// Содержит только константы схемы без SQL-запросов и логики выполнения.
enum DatabaseSchema {
    enum Folders {
        static let table = "folders"

        static let id = "id"
        static let parentFolderId = "parent_folder_id"
        static let rootFolderId = "root_folder_id"
        static let name = "name"
        static let relativePath = "relative_path"
        static let bookmarkBase64 = "bookmark_base64"
        static let isRoot = "is_root"
        static let isAvailable = "is_available"
        static let createdAt = "created_at"
        static let updatedAt = "updated_at"
        static let sortOrder = "sort_order"
        static let lastScannedAt = "last_scanned_at"
        static let trackSortMode = "track_sort_mode"
    }

    enum Tracks {
        static let table = "tracks"

        static let id = "id"
        static let source = "source"
        static let folderId = "folder_id"
        static let rootFolderId = "root_folder_id"
        static let fileName = "file_name"
        static let relativePath = "relative_path"
        static let fileExtension = "file_extension"
        static let fileSize = "file_size"
        static let fileDate = "file_date"
        static let importedAt = "imported_at"
        static let updatedAt = "updated_at"
        static let bookmarkBase64 = "bookmark_base64"
        static let assetURL = "asset_url"
        static let isAvailable = "is_available"
        static let isDeleted = "is_deleted"
    }

    enum TrackMetadata {
        static let table = "track_metadata"

        static let trackId = "track_id"
        static let title = "title"
        static let artist = "artist"
        static let album = "album"
        static let albumArtist = "album_artist"
        static let label = "label"
        static let genre = "genre"
        static let year = "year"
        static let trackNumber = "track_number"
        static let discNumber = "disc_number"
        static let bpm = "bpm"
        static let keySignature = "key_signature"
        static let comment = "comment"
        static let duration = "duration"
        static let bitrate = "bitrate"
        static let sampleRate = "sample_rate"
        static let channelCount = "channel_count"
        static let metadataUpdatedAt = "metadata_updated_at"
    }

    enum TrackIdentityKeys {
        static let table = "track_identity_keys"

        static let identityKey = "identity_key"
        static let trackId = "track_id"
        static let source = "source"
        static let createdAt = "created_at"
        static let updatedAt = "updated_at"
    }

    enum TrackLists {
        static let table = "tracklists"

        static let id = "id"
        static let name = "name"
        static let createdAt = "created_at"
        static let updatedAt = "updated_at"
        static let sortOrder = "sort_order"
        static let isDeleted = "is_deleted"
    }

    enum TrackListTracks {
        static let table = "tracklist_tracks"

        static let id = "id"
        static let trackListId = "tracklist_id"
        static let trackId = "track_id"
        static let position = "position"
        static let sourceSnapshot = "source_snapshot"
        static let titleSnapshot = "title_snapshot"
        static let artistSnapshot = "artist_snapshot"
        static let albumSnapshot = "album_snapshot"
        static let durationSnapshot = "duration_snapshot"
        static let fileNameSnapshot = "file_name_snapshot"
        static let assetURLSnapshot = "asset_url_snapshot"
        static let isAvailableSnapshot = "is_available_snapshot"
        static let createdAt = "created_at"
    }

    enum PlayerQueue {
        static let table = "player_queue"

        static let id = "id"
        static let trackId = "track_id"
        static let position = "position"
        static let sourceSnapshot = "source_snapshot"
        static let titleSnapshot = "title_snapshot"
        static let artistSnapshot = "artist_snapshot"
        static let albumSnapshot = "album_snapshot"
        static let durationSnapshot = "duration_snapshot"
        static let fileNameSnapshot = "file_name_snapshot"
        static let assetURLSnapshot = "asset_url_snapshot"
        static let isAvailableSnapshot = "is_available_snapshot"
        static let createdAt = "created_at"
    }

    enum PlayerState {
        static let table = "player_state"

        static let id = "id"
        static let currentQueueItemId = "current_queue_item_id"
        static let currentTrackId = "current_track_id"
        static let playbackTime = "playback_time"
        static let duration = "duration"
        static let isPlaying = "is_playing"
        static let repeatMode = "repeat_mode"
        static let shuffleEnabled = "shuffle_enabled"
        static let updatedAt = "updated_at"
    }

    enum AppSettings {
        static let table = "app_settings"

        static let id = "id"
        static let schemaVersion = "schema_version"
        static let preferredColorScheme = "preferred_color_scheme"
        static let accentColorName = "accent_color_name"
        static let lastOpenedTab = "last_opened_tab"
        static let isTagReadingEnabled = "is_tag_reading_enabled"
        static let miniPlayerExpanded = "mini_player_expanded"
        static let createdAt = "created_at"
        static let updatedAt = "updated_at"
    }

    enum LibraryViewSettings {
        static let table = "library_view_settings"

        static let id = "id"
        static let sortMode = "sort_mode"
        static let trackListsSortMode = "tracklists_sort_mode"
        static let libraryFoldersSortMode = "library_folders_sort_mode"
        static let groupMode = "group_mode"
        static let showTrackListBadges = "show_tracklist_badges"
        static let showUnavailableTracks = "show_unavailable_tracks"
        static let showFileFormat = "show_file_format"
        static let showPurchasedITunesSource = "show_purchased_itunes_source"
        static let libraryRootDisplayMode = "library_root_display_mode"
        static let lastOpenedFolderId = "last_opened_folder_id"
        static let updatedAt = "updated_at"
    }

    enum PlayerSettings {
        static let table = "player_settings"

        static let id = "id"
        static let autoPlayNext = "auto_play_next"
        static let restoreLastPosition = "restore_last_position"
        static let showMiniPlayer = "show_mini_player"
        static let backgroundPlaybackEnabled = "background_playback_enabled"
        static let repeatMode = "repeat_mode"
        static let shuffleEnabled = "shuffle_enabled"
        static let updatedAt = "updated_at"
    }

}
