//
//  DatabaseQueries.swift
//  TrackList
//
//  Централизованные SQL-запросы слоя SQLite.
//
//  Created by Codex on 04.07.2026.
//

import Foundation

// SQL для таблицы folders.
enum FolderDatabaseQueries {
    static let fetch = """
    SELECT id, parent_folder_id, root_folder_id, name, relative_path, bookmark_base64,
           is_root, is_available, created_at, updated_at, sort_order, last_scanned_at,
           track_sort_mode
    FROM folders
    WHERE id = ?;
    """

    static let fetchRootFolders = """
    SELECT id, parent_folder_id, root_folder_id, name, relative_path, bookmark_base64,
           is_root, is_available, created_at, updated_at, sort_order, last_scanned_at,
           track_sort_mode
    FROM folders
    WHERE is_root = 1
    ORDER BY
        CASE WHEN sort_order IS NULL THEN 1 ELSE 0 END ASC,
        sort_order ASC,
        created_at DESC,
        name COLLATE NOCASE ASC;
    """

    static let fetchAll = """
    SELECT id, parent_folder_id, root_folder_id, name, relative_path, bookmark_base64,
           is_root, is_available, created_at, updated_at, sort_order, last_scanned_at,
           track_sort_mode
    FROM folders
    ORDER BY
        CASE WHEN is_root = 1 THEN 0 ELSE 1 END ASC,
        CASE WHEN sort_order IS NULL THEN 1 ELSE 0 END ASC,
        sort_order ASC,
        root_folder_id COLLATE NOCASE ASC,
        relative_path COLLATE NOCASE ASC,
        name COLLATE NOCASE ASC;
    """

    static let upsert = """
    INSERT INTO folders (
        id, parent_folder_id, root_folder_id, name, relative_path, bookmark_base64,
        is_root, is_available, created_at, updated_at, sort_order, last_scanned_at,
        track_sort_mode
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        parent_folder_id = excluded.parent_folder_id,
        root_folder_id = excluded.root_folder_id,
        name = excluded.name,
        relative_path = excluded.relative_path,
        bookmark_base64 = excluded.bookmark_base64,
        is_root = excluded.is_root,
        is_available = excluded.is_available,
        created_at = excluded.created_at,
        updated_at = excluded.updated_at,
        sort_order = excluded.sort_order,
        last_scanned_at = excluded.last_scanned_at,
        track_sort_mode = excluded.track_sort_mode;
    """

    static let delete = """
    DELETE FROM folders
    WHERE id = ?;
    """

    static let updateBookmark = """
    UPDATE folders
    SET bookmark_base64 = ?, updated_at = ?
    WHERE id = ?;
    """

    static let updateAvailability = """
    UPDATE folders
    SET is_available = ?, updated_at = ?
    WHERE id = ?;
    """

    static let updateSortOrder = """
    UPDATE folders
    SET sort_order = ?, updated_at = ?
    WHERE id = ? AND is_root = 1;
    """

    static let updateTrackSortMode = """
    UPDATE folders
    SET track_sort_mode = ?, updated_at = ?
    WHERE id = ?;
    """
}

// SQL для таблицы tracks.
enum TrackDatabaseQueries {
    static let fetch = """
    SELECT id, source, folder_id, root_folder_id, file_name, relative_path,
           file_extension, file_size, file_date, imported_at, updated_at,
           bookmark_base64, asset_url, is_available, is_deleted
    FROM tracks
    WHERE id = ?;
    """

    static let fetchLibrary = """
    SELECT id, source, folder_id, root_folder_id, file_name, relative_path,
           file_extension, file_size, file_date, imported_at, updated_at,
           bookmark_base64, asset_url, is_available, is_deleted
    FROM tracks
    WHERE id = ? AND source = 'library' AND is_deleted = 0;
    """

    static let fetchImported = """
    SELECT id, source, folder_id, root_folder_id, file_name, relative_path,
           file_extension, file_size, file_date, imported_at, updated_at,
           bookmark_base64, asset_url, is_available, is_deleted
    FROM tracks
    WHERE id = ? AND source = 'imported' AND is_deleted = 0;
    """

    static let fetchActiveLocal = """
    SELECT id, source, folder_id, root_folder_id, file_name, relative_path,
           file_extension, file_size, file_date, imported_at, updated_at,
           bookmark_base64, asset_url, is_available, is_deleted
    FROM tracks
    WHERE id = ? AND source IN ('library', 'imported') AND is_deleted = 0;
    """

    static let fetchAllActiveLocal = """
    SELECT id, source, folder_id, root_folder_id, file_name, relative_path,
           file_extension, file_size, file_date, imported_at, updated_at,
           bookmark_base64, asset_url, is_available, is_deleted
    FROM tracks
    WHERE source IN ('library', 'imported') AND is_deleted = 0
    ORDER BY imported_at DESC;
    """

    static let fetchLibraryForFolder = """
    SELECT id, source, folder_id, root_folder_id, file_name, relative_path,
           file_extension, file_size, file_date, imported_at, updated_at,
           bookmark_base64, asset_url, is_available, is_deleted
    FROM tracks
    WHERE folder_id = ? AND source = 'library' AND is_deleted = 0
    ORDER BY file_date DESC, file_name COLLATE NOCASE DESC, imported_at DESC, id ASC;
    """

    static let fetchLibraryForRoot = """
    SELECT id, source, folder_id, root_folder_id, file_name, relative_path,
           file_extension, file_size, file_date, imported_at, updated_at,
           bookmark_base64, asset_url, is_available, is_deleted
    FROM tracks
    WHERE root_folder_id = ? AND source = 'library' AND is_deleted = 0
    ORDER BY file_date DESC, file_name COLLATE NOCASE DESC, imported_at DESC, id ASC;
    """

    static let fetchLibraryByRootRelativePath = """
    SELECT id, source, folder_id, root_folder_id, file_name, relative_path,
           file_extension, file_size, file_date, imported_at, updated_at,
           bookmark_base64, asset_url, is_available, is_deleted
    FROM tracks
    WHERE root_folder_id = ? AND relative_path = ? AND source = 'library' AND is_deleted = 0
    LIMIT 1;
    """

    static let insert = """
    INSERT INTO tracks (
        id, source, folder_id, root_folder_id, file_name, relative_path,
        file_extension, file_size, file_date, imported_at, updated_at,
        bookmark_base64, asset_url, is_available, is_deleted
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """

    static let upsert = """
    INSERT INTO tracks (
        id, source, folder_id, root_folder_id, file_name, relative_path,
        file_extension, file_size, file_date, imported_at, updated_at,
        bookmark_base64, asset_url, is_available, is_deleted
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        source = excluded.source,
        folder_id = excluded.folder_id,
        root_folder_id = excluded.root_folder_id,
        file_name = excluded.file_name,
        relative_path = excluded.relative_path,
        file_extension = excluded.file_extension,
        file_size = excluded.file_size,
        file_date = excluded.file_date,
        imported_at = excluded.imported_at,
        updated_at = excluded.updated_at,
        bookmark_base64 = excluded.bookmark_base64,
        asset_url = excluded.asset_url,
        is_available = excluded.is_available,
        is_deleted = excluded.is_deleted;
    """

    static let markDeleted = """
    UPDATE tracks
    SET is_deleted = 1, updated_at = ?
    WHERE id = ?;
    """

    static let updateBookmark = """
    UPDATE tracks
    SET bookmark_base64 = ?, updated_at = ?
    WHERE id = ?;
    """

    static let updateAvailability = """
    UPDATE tracks
    SET is_available = ?, updated_at = ?
    WHERE id = ?;
    """
}

// SQL для таблицы track_metadata.
enum TrackMetadataDatabaseQueries {
    static let fetch = """
    SELECT track_id, title, artist, album, album_artist, label, genre, year,
           track_number, disc_number, bpm, key_signature, comment, duration,
           bitrate, sample_rate, channel_count, metadata_updated_at
    FROM track_metadata
    WHERE track_id = ?;
    """

    /// Собирает запрос для пакетного чтения metadata по списку trackId.
    static func fetchAll(trackIdsCount: Int) -> String {
        let placeholders = Array(repeating: "?", count: trackIdsCount).joined(separator: ", ")

        return """
        SELECT track_id, title, artist, album, album_artist, label, genre, year,
               track_number, disc_number, bpm, key_signature, comment, duration,
               bitrate, sample_rate, channel_count, metadata_updated_at
        FROM track_metadata
        WHERE track_id IN (\(placeholders));
        """
    }

    static let upsert = """
    INSERT INTO track_metadata (
        track_id, title, artist, album, album_artist, label, genre, year,
        track_number, disc_number, bpm, key_signature, comment, duration,
        bitrate, sample_rate, channel_count, metadata_updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(track_id) DO UPDATE SET
        title = excluded.title,
        artist = excluded.artist,
        album = excluded.album,
        album_artist = excluded.album_artist,
        label = excluded.label,
        genre = excluded.genre,
        year = excluded.year,
        track_number = excluded.track_number,
        disc_number = excluded.disc_number,
        bpm = excluded.bpm,
        key_signature = excluded.key_signature,
        comment = excluded.comment,
        duration = excluded.duration,
        bitrate = excluded.bitrate,
        sample_rate = excluded.sample_rate,
        channel_count = excluded.channel_count,
        metadata_updated_at = excluded.metadata_updated_at;
    """

    static let delete = """
    DELETE FROM track_metadata
    WHERE track_id = ?;
    """
}

// SQL для таблицы track_identity_keys.
enum TrackIdentityKeyDatabaseQueries {
    static let fetch = """
    SELECT identity_key, track_id, source, created_at, updated_at
    FROM track_identity_keys
    WHERE identity_key = ?;
    """

    static let upsert = """
    INSERT INTO track_identity_keys (
        identity_key, track_id, source, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(identity_key) DO UPDATE SET
        track_id = excluded.track_id,
        source = excluded.source,
        updated_at = excluded.updated_at;
    """

    static let deleteAllForTrack = """
    DELETE FROM track_identity_keys
    WHERE track_id = ?;
    """
}

// SQL для таблицы tracklists.
enum TrackListDatabaseQueries {
    static let fetch = """
    SELECT id, name, created_at, updated_at, sort_order, is_deleted
    FROM tracklists
    WHERE id = ?;
    """

    static let fetchAll = """
    SELECT id, name, created_at, updated_at, sort_order, is_deleted
    FROM tracklists
    ORDER BY sort_order ASC, created_at DESC;
    """

    static let insert = """
    INSERT INTO tracklists (
        id, name, created_at, updated_at, sort_order, is_deleted
    ) VALUES (?, ?, ?, ?, ?, ?);
    """

    static let update = """
    UPDATE tracklists
    SET name = ?, created_at = ?, updated_at = ?, sort_order = ?, is_deleted = ?
    WHERE id = ?;
    """

    static let upsert = """
    INSERT INTO tracklists (
        id, name, created_at, updated_at, sort_order, is_deleted
    ) VALUES (?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        created_at = excluded.created_at,
        updated_at = excluded.updated_at,
        sort_order = excluded.sort_order,
        is_deleted = excluded.is_deleted;
    """

    static let delete = """
    DELETE FROM tracklists
    WHERE id = ?;
    """

    static let markDeleted = """
    UPDATE tracklists
    SET is_deleted = 1, updated_at = ?
    WHERE id = ?;
    """
}

// SQL для таблицы tracklist_tracks.
enum TrackListTrackDatabaseQueries {
    static let fetch = """
    SELECT id, tracklist_id, track_id, position, source_snapshot, title_snapshot,
           artist_snapshot, album_snapshot, duration_snapshot, file_name_snapshot,
           asset_url_snapshot, is_available_snapshot, created_at
    FROM tracklist_tracks
    WHERE id = ?;
    """

    static let fetchAll = """
    SELECT id, tracklist_id, track_id, position, source_snapshot, title_snapshot,
           artist_snapshot, album_snapshot, duration_snapshot, file_name_snapshot,
           asset_url_snapshot, is_available_snapshot, created_at
    FROM tracklist_tracks
    ORDER BY tracklist_id ASC, position ASC;
    """

    static let fetchAllForTrackList = """
    SELECT id, tracklist_id, track_id, position, source_snapshot, title_snapshot,
           artist_snapshot, album_snapshot, duration_snapshot, file_name_snapshot,
           asset_url_snapshot, is_available_snapshot, created_at
    FROM tracklist_tracks
    WHERE tracklist_id = ?
    ORDER BY position ASC;
    """

    static let insert = """
    INSERT INTO tracklist_tracks (
        id, tracklist_id, track_id, position, source_snapshot, title_snapshot,
        artist_snapshot, album_snapshot, duration_snapshot, file_name_snapshot,
        asset_url_snapshot, is_available_snapshot, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """

    static let update = """
    UPDATE tracklist_tracks
    SET tracklist_id = ?, track_id = ?, position = ?, source_snapshot = ?,
        title_snapshot = ?, artist_snapshot = ?, album_snapshot = ?,
        duration_snapshot = ?, file_name_snapshot = ?, asset_url_snapshot = ?,
        is_available_snapshot = ?, created_at = ?
    WHERE id = ?;
    """

    static let upsert = """
    INSERT INTO tracklist_tracks (
        id, tracklist_id, track_id, position, source_snapshot, title_snapshot,
        artist_snapshot, album_snapshot, duration_snapshot, file_name_snapshot,
        asset_url_snapshot, is_available_snapshot, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        tracklist_id = excluded.tracklist_id,
        track_id = excluded.track_id,
        position = excluded.position,
        source_snapshot = excluded.source_snapshot,
        title_snapshot = excluded.title_snapshot,
        artist_snapshot = excluded.artist_snapshot,
        album_snapshot = excluded.album_snapshot,
        duration_snapshot = excluded.duration_snapshot,
        file_name_snapshot = excluded.file_name_snapshot,
        asset_url_snapshot = excluded.asset_url_snapshot,
        is_available_snapshot = excluded.is_available_snapshot,
        created_at = excluded.created_at;
    """

    static let delete = """
    DELETE FROM tracklist_tracks
    WHERE id = ?;
    """

    static let deleteAll = """
    DELETE FROM tracklist_tracks;
    """

    static let deleteForTrackList = """
    DELETE FROM tracklist_tracks
    WHERE tracklist_id = ?;
    """
}

// SQL для таблицы player_queue.
enum PlayerQueueDatabaseQueries {
    static let fetch = """
    SELECT id, track_id, position, source_snapshot, title_snapshot, artist_snapshot,
           album_snapshot, duration_snapshot, file_name_snapshot, asset_url_snapshot,
           is_available_snapshot, created_at
    FROM player_queue
    WHERE id = ?;
    """

    static let fetchAll = """
    SELECT id, track_id, position, source_snapshot, title_snapshot, artist_snapshot,
           album_snapshot, duration_snapshot, file_name_snapshot, asset_url_snapshot,
           is_available_snapshot, created_at
    FROM player_queue
    ORDER BY position ASC;
    """

    static let insert = """
    INSERT INTO player_queue (
        id, track_id, position, source_snapshot, title_snapshot, artist_snapshot,
        album_snapshot, duration_snapshot, file_name_snapshot, asset_url_snapshot,
        is_available_snapshot, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """

    static let update = """
    UPDATE player_queue
    SET track_id = ?, position = ?, source_snapshot = ?, title_snapshot = ?,
        artist_snapshot = ?, album_snapshot = ?, duration_snapshot = ?,
        file_name_snapshot = ?, asset_url_snapshot = ?, is_available_snapshot = ?,
        created_at = ?
    WHERE id = ?;
    """

    static let upsert = """
    INSERT INTO player_queue (
        id, track_id, position, source_snapshot, title_snapshot, artist_snapshot,
        album_snapshot, duration_snapshot, file_name_snapshot, asset_url_snapshot,
        is_available_snapshot, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        track_id = excluded.track_id,
        position = excluded.position,
        source_snapshot = excluded.source_snapshot,
        title_snapshot = excluded.title_snapshot,
        artist_snapshot = excluded.artist_snapshot,
        album_snapshot = excluded.album_snapshot,
        duration_snapshot = excluded.duration_snapshot,
        file_name_snapshot = excluded.file_name_snapshot,
        asset_url_snapshot = excluded.asset_url_snapshot,
        is_available_snapshot = excluded.is_available_snapshot,
        created_at = excluded.created_at;
    """

    static let delete = """
    DELETE FROM player_queue
    WHERE id = ?;
    """

    static let deleteAll = """
    DELETE FROM player_queue;
    """
}

// SQL для таблицы player_state.
enum PlayerStateDatabaseQueries {
    static let fetch = """
    SELECT id, current_queue_item_id, current_track_id, playback_time, duration,
           is_playing, repeat_mode, shuffle_enabled, updated_at
    FROM player_state
    WHERE id = 1;
    """

    static let insert = """
    INSERT INTO player_state (
        id, current_queue_item_id, current_track_id, playback_time, duration,
        is_playing, repeat_mode, shuffle_enabled, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
    """

    static let update = """
    UPDATE player_state
    SET current_queue_item_id = ?, current_track_id = ?, playback_time = ?,
        duration = ?, is_playing = ?, repeat_mode = ?, shuffle_enabled = ?,
        updated_at = ?
    WHERE id = ?;
    """

    static let upsert = """
    INSERT INTO player_state (
        id, current_queue_item_id, current_track_id, playback_time, duration,
        is_playing, repeat_mode, shuffle_enabled, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        current_queue_item_id = excluded.current_queue_item_id,
        current_track_id = excluded.current_track_id,
        playback_time = excluded.playback_time,
        duration = excluded.duration,
        is_playing = excluded.is_playing,
        repeat_mode = excluded.repeat_mode,
        shuffle_enabled = excluded.shuffle_enabled,
        updated_at = excluded.updated_at;
    """

    static let delete = """
    DELETE FROM player_state
    WHERE id = 1;
    """
}

// SQL для таблицы app_settings.
enum AppSettingsDatabaseQueries {
    static let fetch = """
    SELECT id, schema_version, preferred_color_scheme, accent_color_name,
           last_opened_tab, is_tag_reading_enabled, created_at, updated_at
    FROM app_settings
    WHERE id = 1;
    """

    static let insert = """
    INSERT INTO app_settings (
        id, schema_version, preferred_color_scheme, accent_color_name,
        last_opened_tab, is_tag_reading_enabled, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
    """

    static let update = """
    UPDATE app_settings
    SET schema_version = ?, preferred_color_scheme = ?, accent_color_name = ?,
        last_opened_tab = ?, is_tag_reading_enabled = ?, created_at = ?, updated_at = ?
    WHERE id = ?;
    """

    static let upsert = """
    INSERT INTO app_settings (
        id, schema_version, preferred_color_scheme, accent_color_name,
        last_opened_tab, is_tag_reading_enabled, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        schema_version = excluded.schema_version,
        preferred_color_scheme = excluded.preferred_color_scheme,
        accent_color_name = excluded.accent_color_name,
        last_opened_tab = excluded.last_opened_tab,
        is_tag_reading_enabled = excluded.is_tag_reading_enabled,
        created_at = excluded.created_at,
        updated_at = excluded.updated_at;
    """

    static let delete = """
    DELETE FROM app_settings
    WHERE id = 1;
    """
}

// SQL для таблицы library_view_settings.
enum LibraryViewSettingsDatabaseQueries {
    static let fetch = """
    SELECT id, sort_mode, tracklists_sort_mode, library_folders_sort_mode, group_mode,
           show_tracklist_badges, show_unavailable_tracks, show_file_format,
           show_purchased_itunes_source, last_opened_folder_id, updated_at
    FROM library_view_settings
    WHERE id = 1;
    """

    static let insert = """
    INSERT INTO library_view_settings (
        id, sort_mode, tracklists_sort_mode, library_folders_sort_mode, group_mode,
        show_tracklist_badges, show_unavailable_tracks, show_file_format,
        show_purchased_itunes_source, last_opened_folder_id, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """

    static let update = """
    UPDATE library_view_settings
    SET sort_mode = ?, tracklists_sort_mode = ?, library_folders_sort_mode = ?,
        group_mode = ?, show_tracklist_badges = ?, show_unavailable_tracks = ?,
        show_file_format = ?, show_purchased_itunes_source = ?,
        last_opened_folder_id = ?, updated_at = ?
    WHERE id = ?;
    """

    static let upsert = """
    INSERT INTO library_view_settings (
        id, sort_mode, tracklists_sort_mode, library_folders_sort_mode, group_mode,
        show_tracklist_badges, show_unavailable_tracks, show_file_format,
        show_purchased_itunes_source, last_opened_folder_id, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        sort_mode = excluded.sort_mode,
        tracklists_sort_mode = excluded.tracklists_sort_mode,
        library_folders_sort_mode = excluded.library_folders_sort_mode,
        group_mode = excluded.group_mode,
        show_tracklist_badges = excluded.show_tracklist_badges,
        show_unavailable_tracks = excluded.show_unavailable_tracks,
        show_file_format = excluded.show_file_format,
        show_purchased_itunes_source = excluded.show_purchased_itunes_source,
        last_opened_folder_id = excluded.last_opened_folder_id,
        updated_at = excluded.updated_at;
    """

    static let delete = """
    DELETE FROM library_view_settings
    WHERE id = 1;
    """
}

// SQL для таблицы player_settings.
enum PlayerSettingsDatabaseQueries {
    static let fetch = """
    SELECT id, auto_play_next, restore_last_position, show_mini_player,
           background_playback_enabled, updated_at
    FROM player_settings
    WHERE id = 1;
    """

    static let insert = """
    INSERT INTO player_settings (
        id, auto_play_next, restore_last_position, show_mini_player,
        background_playback_enabled, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?);
    """

    static let update = """
    UPDATE player_settings
    SET auto_play_next = ?, restore_last_position = ?, show_mini_player = ?,
        background_playback_enabled = ?, updated_at = ?
    WHERE id = ?;
    """

    static let upsert = """
    INSERT INTO player_settings (
        id, auto_play_next, restore_last_position, show_mini_player,
        background_playback_enabled, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
        auto_play_next = excluded.auto_play_next,
        restore_last_position = excluded.restore_last_position,
        show_mini_player = excluded.show_mini_player,
        background_playback_enabled = excluded.background_playback_enabled,
        updated_at = excluded.updated_at;
    """

    static let delete = """
    DELETE FROM player_settings
    WHERE id = 1;
    """
}
