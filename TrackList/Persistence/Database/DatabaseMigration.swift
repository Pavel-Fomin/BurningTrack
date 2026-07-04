//
//  DatabaseMigration.swift
//  TrackList
//
//  Описывает отдельную миграцию SQLite-схемы.
//
//  Created by Pavel Fomin on 04.07.2026.
//

// Хранит идентификатор миграции и действие, которое изменяет схему базы.
struct DatabaseMigration {
    let identifier: String
    let migrate: (DatabaseConnection) throws -> Void
}

extension DatabaseMigration {
    // Первая миграция фиксирует стартовую версию схемы без создания бизнес-таблиц.
    static let initialSchema = DatabaseMigration(identifier: "001_initial_schema") { _ in
        // Бизнес-таблицы треков, плеера и треклистов появятся в следующих фазах.
    }

    // Вторая миграция создаёт рабочие таблицы SQLite.
    static let initialTables = DatabaseMigration(identifier: "002_initial_tables") { database in
        try database.executeScript(
            """
            CREATE TABLE IF NOT EXISTS folders (
                id TEXT PRIMARY KEY,
                parent_folder_id TEXT,
                root_folder_id TEXT,
                name TEXT NOT NULL,
                relative_path TEXT NOT NULL,
                bookmark_base64 TEXT,
                is_root INTEGER NOT NULL DEFAULT 0 CHECK (is_root IN (0, 1)),
                is_available INTEGER NOT NULL DEFAULT 1 CHECK (is_available IN (0, 1)),
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                last_scanned_at TEXT,
                FOREIGN KEY (parent_folder_id) REFERENCES folders(id) ON DELETE CASCADE,
                FOREIGN KEY (root_folder_id) REFERENCES folders(id) ON DELETE CASCADE
            );

            CREATE UNIQUE INDEX IF NOT EXISTS idx_folders_unique_root_path
            ON folders(root_folder_id, relative_path);

            CREATE INDEX IF NOT EXISTS idx_folders_root_folder_id
            ON folders(root_folder_id);

            CREATE INDEX IF NOT EXISTS idx_folders_parent_folder_id
            ON folders(parent_folder_id);

            CREATE INDEX IF NOT EXISTS idx_folders_relative_path
            ON folders(relative_path);

            CREATE TABLE IF NOT EXISTS tracks (
                id TEXT PRIMARY KEY,
                source TEXT NOT NULL CHECK (source IN ('library', 'purchasedITunes')),
                folder_id TEXT,
                root_folder_id TEXT,
                file_name TEXT NOT NULL,
                relative_path TEXT,
                file_extension TEXT,
                file_size INTEGER,
                file_date TEXT,
                imported_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                bookmark_base64 TEXT,
                asset_url TEXT,
                is_available INTEGER NOT NULL DEFAULT 1 CHECK (is_available IN (0, 1)),
                is_deleted INTEGER NOT NULL DEFAULT 0 CHECK (is_deleted IN (0, 1)),
                FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE SET NULL,
                FOREIGN KEY (root_folder_id) REFERENCES folders(id) ON DELETE CASCADE
            );

            CREATE UNIQUE INDEX IF NOT EXISTS idx_tracks_unique_library_path
            ON tracks(root_folder_id, relative_path)
            WHERE source = 'library' AND is_deleted = 0;

            CREATE INDEX IF NOT EXISTS idx_tracks_source
            ON tracks(source);

            CREATE INDEX IF NOT EXISTS idx_tracks_folder_id
            ON tracks(folder_id);

            CREATE INDEX IF NOT EXISTS idx_tracks_root_folder_id
            ON tracks(root_folder_id);

            CREATE INDEX IF NOT EXISTS idx_tracks_file_date
            ON tracks(file_date);

            CREATE INDEX IF NOT EXISTS idx_tracks_imported_at
            ON tracks(imported_at);

            CREATE INDEX IF NOT EXISTS idx_tracks_is_available
            ON tracks(is_available);

            CREATE INDEX IF NOT EXISTS idx_tracks_root_relative_path
            ON tracks(root_folder_id, relative_path);

            CREATE TABLE IF NOT EXISTS track_metadata (
                track_id TEXT PRIMARY KEY,
                title TEXT,
                artist TEXT,
                album TEXT,
                album_artist TEXT,
                genre TEXT,
                year INTEGER,
                track_number INTEGER,
                disc_number INTEGER,
                bpm REAL,
                key_signature TEXT,
                comment TEXT,
                duration REAL,
                bitrate INTEGER,
                sample_rate INTEGER,
                channel_count INTEGER,
                metadata_updated_at TEXT NOT NULL,
                FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_track_metadata_title
            ON track_metadata(title);

            CREATE INDEX IF NOT EXISTS idx_track_metadata_artist
            ON track_metadata(artist);

            CREATE INDEX IF NOT EXISTS idx_track_metadata_album
            ON track_metadata(album);

            CREATE INDEX IF NOT EXISTS idx_track_metadata_duration
            ON track_metadata(duration);

            CREATE TABLE IF NOT EXISTS tracklists (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                sort_order INTEGER,
                is_deleted INTEGER NOT NULL DEFAULT 0 CHECK (is_deleted IN (0, 1))
            );

            CREATE INDEX IF NOT EXISTS idx_tracklists_created_at
            ON tracklists(created_at);

            CREATE INDEX IF NOT EXISTS idx_tracklists_sort_order
            ON tracklists(sort_order);

            CREATE INDEX IF NOT EXISTS idx_tracklists_is_deleted
            ON tracklists(is_deleted);

            CREATE TABLE IF NOT EXISTS tracklist_tracks (
                id TEXT PRIMARY KEY,
                tracklist_id TEXT NOT NULL,
                track_id TEXT NOT NULL,
                position INTEGER NOT NULL,
                source_snapshot TEXT NOT NULL CHECK (source_snapshot IN ('library', 'purchasedITunes')),
                title_snapshot TEXT,
                artist_snapshot TEXT,
                album_snapshot TEXT,
                duration_snapshot REAL,
                file_name_snapshot TEXT,
                asset_url_snapshot TEXT,
                is_available_snapshot INTEGER NOT NULL DEFAULT 1 CHECK (is_available_snapshot IN (0, 1)),
                created_at TEXT NOT NULL,
                FOREIGN KEY (tracklist_id) REFERENCES tracklists(id) ON DELETE CASCADE
            );

            CREATE UNIQUE INDEX IF NOT EXISTS idx_tracklist_tracks_unique_position
            ON tracklist_tracks(tracklist_id, position);

            CREATE INDEX IF NOT EXISTS idx_tracklist_tracks_tracklist_id
            ON tracklist_tracks(tracklist_id);

            CREATE INDEX IF NOT EXISTS idx_tracklist_tracks_track_id
            ON tracklist_tracks(track_id);

            CREATE INDEX IF NOT EXISTS idx_tracklist_tracks_position
            ON tracklist_tracks(position);

            CREATE TABLE IF NOT EXISTS player_queue (
                id TEXT PRIMARY KEY,
                track_id TEXT NOT NULL,
                position INTEGER NOT NULL,
                source_snapshot TEXT NOT NULL CHECK (source_snapshot IN ('library', 'purchasedITunes')),
                title_snapshot TEXT,
                artist_snapshot TEXT,
                album_snapshot TEXT,
                duration_snapshot REAL,
                file_name_snapshot TEXT,
                asset_url_snapshot TEXT,
                is_available_snapshot INTEGER NOT NULL DEFAULT 1 CHECK (is_available_snapshot IN (0, 1)),
                created_at TEXT NOT NULL,
                FOREIGN KEY (track_id) REFERENCES tracks(id)
            );

            CREATE UNIQUE INDEX IF NOT EXISTS idx_player_queue_unique_position
            ON player_queue(position);

            CREATE INDEX IF NOT EXISTS idx_player_queue_position
            ON player_queue(position);

            CREATE INDEX IF NOT EXISTS idx_player_queue_track_id
            ON player_queue(track_id);

            CREATE TABLE IF NOT EXISTS player_state (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                current_queue_item_id TEXT,
                current_track_id TEXT,
                playback_time REAL NOT NULL DEFAULT 0,
                duration REAL,
                is_playing INTEGER NOT NULL DEFAULT 0 CHECK (is_playing IN (0, 1)),
                repeat_mode TEXT NOT NULL DEFAULT 'off' CHECK (repeat_mode IN ('off', 'one', 'all')),
                shuffle_enabled INTEGER NOT NULL DEFAULT 0 CHECK (shuffle_enabled IN (0, 1)),
                updated_at TEXT NOT NULL,
                FOREIGN KEY (current_queue_item_id) REFERENCES player_queue(id) ON DELETE SET NULL,
                FOREIGN KEY (current_track_id) REFERENCES tracks(id) ON DELETE SET NULL
            );

            CREATE TABLE IF NOT EXISTS app_settings (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                schema_version INTEGER NOT NULL DEFAULT 1,
                preferred_color_scheme TEXT NOT NULL DEFAULT 'system' CHECK (preferred_color_scheme IN ('system', 'light', 'dark')),
                accent_color_name TEXT,
                last_opened_tab TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS library_view_settings (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                sort_mode TEXT NOT NULL DEFAULT 'fileDateDesc',
                group_mode TEXT NOT NULL DEFAULT 'date',
                show_tracklist_badges INTEGER NOT NULL DEFAULT 1 CHECK (show_tracklist_badges IN (0, 1)),
                show_unavailable_tracks INTEGER NOT NULL DEFAULT 1 CHECK (show_unavailable_tracks IN (0, 1)),
                last_opened_folder_id TEXT,
                updated_at TEXT NOT NULL,
                FOREIGN KEY (last_opened_folder_id) REFERENCES folders(id) ON DELETE SET NULL
            );

            CREATE TABLE IF NOT EXISTS player_settings (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                auto_play_next INTEGER NOT NULL DEFAULT 1 CHECK (auto_play_next IN (0, 1)),
                restore_last_position INTEGER NOT NULL DEFAULT 1 CHECK (restore_last_position IN (0, 1)),
                show_mini_player INTEGER NOT NULL DEFAULT 1 CHECK (show_mini_player IN (0, 1)),
                background_playback_enabled INTEGER NOT NULL DEFAULT 1 CHECK (background_playback_enabled IN (0, 1)),
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS export_settings (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                filename_template TEXT NOT NULL DEFAULT 'original',
                include_tracklist_prefix INTEGER NOT NULL DEFAULT 0 CHECK (include_tracklist_prefix IN (0, 1)),
                prefix_format TEXT NOT NULL DEFAULT '001',
                duplicate_handling TEXT NOT NULL DEFAULT 'keepBoth' CHECK (duplicate_handling IN ('keepBoth', 'skip', 'replace')),
                create_m3u INTEGER NOT NULL DEFAULT 0 CHECK (create_m3u IN (0, 1)),
                export_artwork INTEGER NOT NULL DEFAULT 0 CHECK (export_artwork IN (0, 1)),
                updated_at TEXT NOT NULL
            );
            """,
        )
    }

    // Третья миграция разрешает треклистам хранить внешние track_id из iTunes.
    static let trackListTracksAllowExternalTrackIds = DatabaseMigration(identifier: "003_tracklist_tracks_allow_external_track_ids") { database in
        try database.executeScript(
            """
            CREATE TABLE IF NOT EXISTS tracklist_tracks_rebuilt (
                id TEXT PRIMARY KEY,
                tracklist_id TEXT NOT NULL,
                track_id TEXT NOT NULL,
                position INTEGER NOT NULL,
                source_snapshot TEXT NOT NULL CHECK (source_snapshot IN ('library', 'purchasedITunes')),
                title_snapshot TEXT,
                artist_snapshot TEXT,
                album_snapshot TEXT,
                duration_snapshot REAL,
                file_name_snapshot TEXT,
                asset_url_snapshot TEXT,
                is_available_snapshot INTEGER NOT NULL DEFAULT 1 CHECK (is_available_snapshot IN (0, 1)),
                created_at TEXT NOT NULL,
                FOREIGN KEY (tracklist_id) REFERENCES tracklists(id) ON DELETE CASCADE
            );

            INSERT INTO tracklist_tracks_rebuilt (
                id, tracklist_id, track_id, position, source_snapshot, title_snapshot,
                artist_snapshot, album_snapshot, duration_snapshot, file_name_snapshot,
                asset_url_snapshot, is_available_snapshot, created_at
            )
            SELECT id, tracklist_id, track_id, position, source_snapshot, title_snapshot,
                   artist_snapshot, album_snapshot, duration_snapshot, file_name_snapshot,
                   asset_url_snapshot, is_available_snapshot, created_at
            FROM tracklist_tracks;

            DROP TABLE tracklist_tracks;

            ALTER TABLE tracklist_tracks_rebuilt RENAME TO tracklist_tracks;

            CREATE UNIQUE INDEX IF NOT EXISTS idx_tracklist_tracks_unique_position
            ON tracklist_tracks(tracklist_id, position);

            CREATE INDEX IF NOT EXISTS idx_tracklist_tracks_tracklist_id
            ON tracklist_tracks(tracklist_id);

            CREATE INDEX IF NOT EXISTS idx_tracklist_tracks_track_id
            ON tracklist_tracks(track_id);

            CREATE INDEX IF NOT EXISTS idx_tracklist_tracks_position
            ON tracklist_tracks(position);
            """,
        )
    }
}
