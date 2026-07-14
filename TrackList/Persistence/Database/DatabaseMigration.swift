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
    // Единый порядок миграций используется приложением, тестами и генератором документации схемы.
    static let all: [DatabaseMigration] = [
        .initialSchema,
        .initialTables,
        .trackListTracksAllowExternalTrackIds,
        .settingsPhase7,
        .importedTracksPhase8,
        .trackListsSortModeSetting,
        .libraryFoldersSorting,
        .trackMetadataLabel,
        .folderTrackSortMode,
        .libraryRootDisplayModeSetting,
        .libraryRootDisplayModeColumnRepair,
        .playbackModeSettings,
        .miniPlayerPresentationState
    ]

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
                sort_order INTEGER,
                last_scanned_at TEXT,
                track_sort_mode TEXT,
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

            CREATE INDEX IF NOT EXISTS idx_folders_sort_order
            ON folders(sort_order);

            CREATE TABLE IF NOT EXISTS tracks (
                id TEXT PRIMARY KEY,
                source TEXT NOT NULL CHECK (source IN ('library', 'imported', 'purchasedITunes')),
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
                label TEXT,
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

            CREATE TABLE IF NOT EXISTS track_identity_keys (
                identity_key TEXT PRIMARY KEY,
                track_id TEXT NOT NULL,
                source TEXT NOT NULL CHECK (source IN ('imported')),
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_track_identity_keys_track_id
            ON track_identity_keys(track_id);

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
                source_snapshot TEXT NOT NULL CHECK (source_snapshot IN ('library', 'imported', 'purchasedITunes')),
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
                source_snapshot TEXT NOT NULL CHECK (source_snapshot IN ('library', 'imported', 'purchasedITunes')),
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
                is_tag_reading_enabled INTEGER NOT NULL DEFAULT 1 CHECK (is_tag_reading_enabled IN (0, 1)),
                mini_player_expanded INTEGER NOT NULL DEFAULT 0 CHECK (mini_player_expanded IN (0, 1)),
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS library_view_settings (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                sort_mode TEXT NOT NULL DEFAULT 'fileDateDesc',
                tracklists_sort_mode TEXT CHECK (tracklists_sort_mode IN ('createdAt', 'name')),
                library_folders_sort_mode TEXT CHECK (library_folders_sort_mode IN ('createdAt', 'name')),
                group_mode TEXT NOT NULL DEFAULT 'date',
                show_tracklist_badges INTEGER NOT NULL DEFAULT 1 CHECK (show_tracklist_badges IN (0, 1)),
                show_unavailable_tracks INTEGER NOT NULL DEFAULT 1 CHECK (show_unavailable_tracks IN (0, 1)),
                show_file_format INTEGER NOT NULL DEFAULT 1 CHECK (show_file_format IN (0, 1)),
                show_purchased_itunes_source INTEGER NOT NULL DEFAULT 1 CHECK (show_purchased_itunes_source IN (0, 1)),
                library_root_display_mode TEXT CHECK (library_root_display_mode IN ('folders', 'tracks')),
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
                repeat_mode TEXT NOT NULL DEFAULT 'off' CHECK (repeat_mode IN ('off', 'one', 'all')),
                shuffle_enabled INTEGER NOT NULL DEFAULT 0 CHECK (shuffle_enabled IN (0, 1)),
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
                source_snapshot TEXT NOT NULL CHECK (source_snapshot IN ('library', 'imported', 'purchasedITunes')),
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

    // Четвёртая миграция добавляет недостающие SQLite-колонки пользовательских настроек.
    static let settingsPhase7 = DatabaseMigration(identifier: "004_settings_phase_7") { database in
        try ensureColumn(
            "is_tag_reading_enabled",
            in: "app_settings",
            definition: "INTEGER NOT NULL DEFAULT 1 CHECK (is_tag_reading_enabled IN (0, 1))",
            database: database
        )
        try ensureColumn(
            "show_file_format",
            in: "library_view_settings",
            definition: "INTEGER NOT NULL DEFAULT 1 CHECK (show_file_format IN (0, 1))",
            database: database
        )
        try ensureColumn(
            "show_purchased_itunes_source",
            in: "library_view_settings",
            definition: "INTEGER NOT NULL DEFAULT 1 CHECK (show_purchased_itunes_source IN (0, 1))",
            database: database
        )
    }

    // Пятая миграция добавляет источник imported и SQLite-таблицу стабильных identity-ключей.
    static let importedTracksPhase8 = DatabaseMigration(identifier: "005_imported_tracks_phase_8") { database in
        try database.executeScript(
            """
            PRAGMA defer_foreign_keys = ON;

            CREATE TABLE track_metadata_backup AS SELECT * FROM track_metadata;
            CREATE TABLE player_queue_backup AS SELECT * FROM player_queue;
            CREATE TABLE player_state_backup AS SELECT * FROM player_state;

            DROP TABLE track_metadata;
            DROP TABLE player_queue;
            DROP TABLE player_state;

            CREATE TABLE tracks_rebuilt (
                id TEXT PRIMARY KEY,
                source TEXT NOT NULL CHECK (source IN ('library', 'imported', 'purchasedITunes')),
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

            INSERT INTO tracks_rebuilt (
                id, source, folder_id, root_folder_id, file_name, relative_path,
                file_extension, file_size, file_date, imported_at, updated_at,
                bookmark_base64, asset_url, is_available, is_deleted
            )
            SELECT id, source, folder_id, root_folder_id, file_name, relative_path,
                   file_extension, file_size, file_date, imported_at, updated_at,
                   bookmark_base64, asset_url, is_available, is_deleted
            FROM tracks;

            DROP TABLE tracks;
            ALTER TABLE tracks_rebuilt RENAME TO tracks;

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

            CREATE TABLE track_metadata (
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

            INSERT INTO track_metadata (
                track_id, title, artist, album, album_artist, genre, year, track_number,
                disc_number, bpm, key_signature, comment, duration, bitrate, sample_rate,
                channel_count, metadata_updated_at
            )
            SELECT track_id, title, artist, album, album_artist, genre, year, track_number,
                   disc_number, bpm, key_signature, comment, duration, bitrate, sample_rate,
                   channel_count, metadata_updated_at
            FROM track_metadata_backup;

            DROP TABLE track_metadata_backup;

            CREATE INDEX IF NOT EXISTS idx_track_metadata_title
            ON track_metadata(title);

            CREATE INDEX IF NOT EXISTS idx_track_metadata_artist
            ON track_metadata(artist);

            CREATE INDEX IF NOT EXISTS idx_track_metadata_album
            ON track_metadata(album);

            CREATE INDEX IF NOT EXISTS idx_track_metadata_duration
            ON track_metadata(duration);

            CREATE TABLE player_queue (
                id TEXT PRIMARY KEY,
                track_id TEXT NOT NULL,
                position INTEGER NOT NULL,
                source_snapshot TEXT NOT NULL CHECK (source_snapshot IN ('library', 'imported', 'purchasedITunes')),
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

            INSERT INTO player_queue (
                id, track_id, position, source_snapshot, title_snapshot, artist_snapshot,
                album_snapshot, duration_snapshot, file_name_snapshot, asset_url_snapshot,
                is_available_snapshot, created_at
            )
            SELECT id, track_id, position, source_snapshot, title_snapshot, artist_snapshot,
                   album_snapshot, duration_snapshot, file_name_snapshot, asset_url_snapshot,
                   is_available_snapshot, created_at
            FROM player_queue_backup;

            DROP TABLE player_queue_backup;

            CREATE UNIQUE INDEX IF NOT EXISTS idx_player_queue_unique_position
            ON player_queue(position);

            CREATE INDEX IF NOT EXISTS idx_player_queue_position
            ON player_queue(position);

            CREATE INDEX IF NOT EXISTS idx_player_queue_track_id
            ON player_queue(track_id);

            CREATE TABLE player_state (
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

            INSERT INTO player_state (
                id, current_queue_item_id, current_track_id, playback_time, duration,
                is_playing, repeat_mode, shuffle_enabled, updated_at
            )
            SELECT id, current_queue_item_id, current_track_id, playback_time, duration,
                   is_playing, repeat_mode, shuffle_enabled, updated_at
            FROM player_state_backup;

            DROP TABLE player_state_backup;

            CREATE TABLE tracklist_tracks_rebuilt (
                id TEXT PRIMARY KEY,
                tracklist_id TEXT NOT NULL,
                track_id TEXT NOT NULL,
                position INTEGER NOT NULL,
                source_snapshot TEXT NOT NULL CHECK (source_snapshot IN ('library', 'imported', 'purchasedITunes')),
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

            CREATE TABLE IF NOT EXISTS track_identity_keys (
                identity_key TEXT PRIMARY KEY,
                track_id TEXT NOT NULL,
                source TEXT NOT NULL CHECK (source IN ('imported')),
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_track_identity_keys_track_id
            ON track_identity_keys(track_id);
            """,
        )
    }

    // Шестая миграция сохраняет последний выбранный режим сортировки списка треклистов.
    static let trackListsSortModeSetting = DatabaseMigration(identifier: "006_tracklists_sort_mode_setting") { database in
        try ensureColumn(
            "tracklists_sort_mode",
            in: "library_view_settings",
            definition: "TEXT CHECK (tracklists_sort_mode IN ('createdAt', 'name'))",
            database: database
        )
    }

    // Седьмая миграция добавляет ручной порядок и выбранный режим сортировки прикреплённых папок.
    static let libraryFoldersSorting = DatabaseMigration(identifier: "007_library_folders_sorting") { database in
        try ensureColumn(
            "sort_order",
            in: "folders",
            definition: "INTEGER",
            database: database
        )
        try ensureColumn(
            "library_folders_sort_mode",
            in: "library_view_settings",
            definition: "TEXT CHECK (library_folders_sort_mode IN ('createdAt', 'name'))",
            database: database
        )

        // Индекс ускоряет чтение корневых папок в сохранённом ручном порядке.
        try database.executeScript(
            """
            CREATE INDEX IF NOT EXISTS idx_folders_sort_order
            ON folders(sort_order);
            """,
        )
    }

    // Восьмая миграция добавляет сохранённый лейбл для сортировки фонотеки.
    static let trackMetadataLabel = DatabaseMigration(identifier: "008_track_metadata_label") { database in
        try ensureColumn(
            "label",
            in: "track_metadata",
            definition: "TEXT",
            database: database
        )
    }

    // Девятая миграция сохраняет режим сортировки треков отдельно для каждой папки фонотеки.
    static let folderTrackSortMode = DatabaseMigration(identifier: "009_folder_track_sort_mode") { database in
        try ensureColumn(
            "track_sort_mode",
            in: "folders",
            definition: "TEXT",
            database: database
        )
    }

    // Десятая миграция добавляет сохранение последнего режима корня фонотеки.
    static let libraryRootDisplayModeSetting = DatabaseMigration(identifier: "010_library_root_display_mode_setting") { database in
        try ensureColumn(
            "library_root_display_mode",
            in: "library_view_settings",
            definition: "TEXT CHECK (library_root_display_mode IN ('folders', 'tracks'))",
            database: database
        )
    }

    // Одиннадцатая миграция повторно проверяет колонку режима для баз, где идентификатор предыдущей миграции уже был записан.
    static let libraryRootDisplayModeColumnRepair = DatabaseMigration(identifier: "011_library_root_display_mode_column_repair") { database in
        try ensureColumn(
            "library_root_display_mode",
            in: "library_view_settings",
            definition: "TEXT CHECK (library_root_display_mode IN ('folders', 'tracks'))",
            database: database
        )
    }

    // Двенадцатая миграция добавляет постоянный режим воспроизведения в настройки плеера.
    static let playbackModeSettings = DatabaseMigration(identifier: "012_playback_mode_settings") { database in
        try ensureColumn(
            "repeat_mode",
            in: "player_settings",
            definition: "TEXT NOT NULL DEFAULT 'off' CHECK (repeat_mode IN ('off', 'one', 'all'))",
            database: database
        )
        try ensureColumn(
            "shuffle_enabled",
            in: "player_settings",
            definition: "INTEGER NOT NULL DEFAULT 0 CHECK (shuffle_enabled IN (0, 1))",
            database: database
        )
    }

    // Тринадцатая миграция добавляет сохранение состояния раскрытия мини-плеера в общие настройки приложения.
    static let miniPlayerPresentationState = DatabaseMigration(identifier: "013_mini_player_presentation_state") { database in
        try ensureColumn(
            "mini_player_expanded",
            in: "app_settings",
            definition: "INTEGER NOT NULL DEFAULT 0 CHECK (mini_player_expanded IN (0, 1))",
            database: database
        )
    }

    private static func ensureColumn(
        _ column: String,
        in table: String,
        definition: String,
        database: DatabaseConnection
    ) throws {
        let existingColumns = try columnNames(in: table, database: database)
        guard existingColumns.contains(column) == false else { return }

        // Имена таблиц и колонок приходят только из кода миграции, поэтому DDL не принимает пользовательский ввод.
        try database.executeScript(
            "ALTER TABLE \(table) ADD COLUMN \(column) \(definition);"
        )
    }

    private static func columnNames(
        in table: String,
        database: DatabaseConnection
    ) throws -> Set<String> {
        let statement = try database.prepare("PRAGMA table_info(\(table));")
        var names = Set<String>()

        while try statement.step() == .row {
            names.insert(try statement.rowReader().requiredString(at: 1))
        }

        return names
    }
}
