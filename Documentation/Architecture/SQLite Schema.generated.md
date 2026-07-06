# SQLite Schema (Generated)

> Этот файл является снимком фактической SQLite-схемы.
> Он генерируется из временной базы после применения migrations.
> Не редактировать вручную: любые изменения будут перезаписаны при следующей генерации.

## Tables

| Table | Columns | Foreign Keys | Indexes |
| --- | ---: | ---: | ---: |
| app_settings | 8 | 0 | 0 |
| folders | 11 | 2 | 5 |
| library_view_settings | 9 | 1 | 0 |
| player_queue | 12 | 1 | 4 |
| player_settings | 6 | 0 | 0 |
| player_state | 9 | 2 | 0 |
| schema_migrations | 2 | 0 | 1 |
| track_identity_keys | 5 | 1 | 2 |
| track_metadata | 17 | 1 | 5 |
| tracklist_tracks | 13 | 1 | 5 |
| tracklists | 6 | 0 | 4 |
| tracks | 15 | 2 | 9 |

## app_settings

### Columns

| Name | Type | Not Null | Default | Primary Key | Hidden |
| --- | --- | --- | --- | --- | --- |
| id | INTEGER | no | - | 1 | 0 |
| schema_version | INTEGER | yes | 1 | 0 | 0 |
| preferred_color_scheme | TEXT | yes | 'system' | 0 | 0 |
| accent_color_name | TEXT | no | - | 0 | 0 |
| last_opened_tab | TEXT | no | - | 0 | 0 |
| is_tag_reading_enabled | INTEGER | yes | 1 | 0 | 0 |
| created_at | TEXT | yes | - | 0 | 0 |
| updated_at | TEXT | yes | - | 0 | 0 |

### Foreign Keys

No foreign keys.

### Indexes

No indexes.

## folders

### Columns

| Name | Type | Not Null | Default | Primary Key | Hidden |
| --- | --- | --- | --- | --- | --- |
| id | TEXT | no | - | 1 | 0 |
| parent_folder_id | TEXT | no | - | 0 | 0 |
| root_folder_id | TEXT | no | - | 0 | 0 |
| name | TEXT | yes | - | 0 | 0 |
| relative_path | TEXT | yes | - | 0 | 0 |
| bookmark_base64 | TEXT | no | - | 0 | 0 |
| is_root | INTEGER | yes | 0 | 0 | 0 |
| is_available | INTEGER | yes | 1 | 0 | 0 |
| created_at | TEXT | yes | - | 0 | 0 |
| updated_at | TEXT | yes | - | 0 | 0 |
| last_scanned_at | TEXT | no | - | 0 | 0 |

### Foreign Keys

| Id | Seq | From | Target Table | Target Column | On Update | On Delete | Match |
| ---: | ---: | --- | --- | --- | --- | --- | --- |
| 0 | 0 | root_folder_id | folders | id | NO ACTION | CASCADE | NONE |
| 1 | 0 | parent_folder_id | folders | id | NO ACTION | CASCADE | NONE |

### Indexes

| Name | Unique | Origin | Partial | Columns |
| --- | --- | --- | --- | --- |
| idx_folders_parent_folder_id | no | c | no | parent_folder_id |
| idx_folders_relative_path | no | c | no | relative_path |
| idx_folders_root_folder_id | no | c | no | root_folder_id |
| idx_folders_unique_root_path | yes | c | no | root_folder_id, relative_path |
| sqlite_autoindex_folders_1 | yes | pk | no | id |

## library_view_settings

### Columns

| Name | Type | Not Null | Default | Primary Key | Hidden |
| --- | --- | --- | --- | --- | --- |
| id | INTEGER | no | - | 1 | 0 |
| sort_mode | TEXT | yes | 'fileDateDesc' | 0 | 0 |
| group_mode | TEXT | yes | 'date' | 0 | 0 |
| show_tracklist_badges | INTEGER | yes | 1 | 0 | 0 |
| show_unavailable_tracks | INTEGER | yes | 1 | 0 | 0 |
| show_file_format | INTEGER | yes | 1 | 0 | 0 |
| show_purchased_itunes_source | INTEGER | yes | 1 | 0 | 0 |
| last_opened_folder_id | TEXT | no | - | 0 | 0 |
| updated_at | TEXT | yes | - | 0 | 0 |

### Foreign Keys

| Id | Seq | From | Target Table | Target Column | On Update | On Delete | Match |
| ---: | ---: | --- | --- | --- | --- | --- | --- |
| 0 | 0 | last_opened_folder_id | folders | id | NO ACTION | SET NULL | NONE |

### Indexes

No indexes.

## player_queue

### Columns

| Name | Type | Not Null | Default | Primary Key | Hidden |
| --- | --- | --- | --- | --- | --- |
| id | TEXT | no | - | 1 | 0 |
| track_id | TEXT | yes | - | 0 | 0 |
| position | INTEGER | yes | - | 0 | 0 |
| source_snapshot | TEXT | yes | - | 0 | 0 |
| title_snapshot | TEXT | no | - | 0 | 0 |
| artist_snapshot | TEXT | no | - | 0 | 0 |
| album_snapshot | TEXT | no | - | 0 | 0 |
| duration_snapshot | REAL | no | - | 0 | 0 |
| file_name_snapshot | TEXT | no | - | 0 | 0 |
| asset_url_snapshot | TEXT | no | - | 0 | 0 |
| is_available_snapshot | INTEGER | yes | 1 | 0 | 0 |
| created_at | TEXT | yes | - | 0 | 0 |

### Foreign Keys

| Id | Seq | From | Target Table | Target Column | On Update | On Delete | Match |
| ---: | ---: | --- | --- | --- | --- | --- | --- |
| 0 | 0 | track_id | tracks | id | NO ACTION | NO ACTION | NONE |

### Indexes

| Name | Unique | Origin | Partial | Columns |
| --- | --- | --- | --- | --- |
| idx_player_queue_position | no | c | no | position |
| idx_player_queue_track_id | no | c | no | track_id |
| idx_player_queue_unique_position | yes | c | no | position |
| sqlite_autoindex_player_queue_1 | yes | pk | no | id |

## player_settings

### Columns

| Name | Type | Not Null | Default | Primary Key | Hidden |
| --- | --- | --- | --- | --- | --- |
| id | INTEGER | no | - | 1 | 0 |
| auto_play_next | INTEGER | yes | 1 | 0 | 0 |
| restore_last_position | INTEGER | yes | 1 | 0 | 0 |
| show_mini_player | INTEGER | yes | 1 | 0 | 0 |
| background_playback_enabled | INTEGER | yes | 1 | 0 | 0 |
| updated_at | TEXT | yes | - | 0 | 0 |

### Foreign Keys

No foreign keys.

### Indexes

No indexes.

## player_state

### Columns

| Name | Type | Not Null | Default | Primary Key | Hidden |
| --- | --- | --- | --- | --- | --- |
| id | INTEGER | no | - | 1 | 0 |
| current_queue_item_id | TEXT | no | - | 0 | 0 |
| current_track_id | TEXT | no | - | 0 | 0 |
| playback_time | REAL | yes | 0 | 0 | 0 |
| duration | REAL | no | - | 0 | 0 |
| is_playing | INTEGER | yes | 0 | 0 | 0 |
| repeat_mode | TEXT | yes | 'off' | 0 | 0 |
| shuffle_enabled | INTEGER | yes | 0 | 0 | 0 |
| updated_at | TEXT | yes | - | 0 | 0 |

### Foreign Keys

| Id | Seq | From | Target Table | Target Column | On Update | On Delete | Match |
| ---: | ---: | --- | --- | --- | --- | --- | --- |
| 0 | 0 | current_track_id | tracks | id | NO ACTION | SET NULL | NONE |
| 1 | 0 | current_queue_item_id | player_queue | id | NO ACTION | SET NULL | NONE |

### Indexes

No indexes.

## schema_migrations

### Columns

| Name | Type | Not Null | Default | Primary Key | Hidden |
| --- | --- | --- | --- | --- | --- |
| identifier | TEXT | yes | - | 1 | 0 |
| applied_at | TEXT | yes | - | 0 | 0 |

### Foreign Keys

No foreign keys.

### Indexes

| Name | Unique | Origin | Partial | Columns |
| --- | --- | --- | --- | --- |
| sqlite_autoindex_schema_migrations_1 | yes | pk | no | identifier |

## track_identity_keys

### Columns

| Name | Type | Not Null | Default | Primary Key | Hidden |
| --- | --- | --- | --- | --- | --- |
| identity_key | TEXT | no | - | 1 | 0 |
| track_id | TEXT | yes | - | 0 | 0 |
| source | TEXT | yes | - | 0 | 0 |
| created_at | TEXT | yes | - | 0 | 0 |
| updated_at | TEXT | yes | - | 0 | 0 |

### Foreign Keys

| Id | Seq | From | Target Table | Target Column | On Update | On Delete | Match |
| ---: | ---: | --- | --- | --- | --- | --- | --- |
| 0 | 0 | track_id | tracks | id | NO ACTION | CASCADE | NONE |

### Indexes

| Name | Unique | Origin | Partial | Columns |
| --- | --- | --- | --- | --- |
| idx_track_identity_keys_track_id | no | c | no | track_id |
| sqlite_autoindex_track_identity_keys_1 | yes | pk | no | identity_key |

## track_metadata

### Columns

| Name | Type | Not Null | Default | Primary Key | Hidden |
| --- | --- | --- | --- | --- | --- |
| track_id | TEXT | no | - | 1 | 0 |
| title | TEXT | no | - | 0 | 0 |
| artist | TEXT | no | - | 0 | 0 |
| album | TEXT | no | - | 0 | 0 |
| album_artist | TEXT | no | - | 0 | 0 |
| genre | TEXT | no | - | 0 | 0 |
| year | INTEGER | no | - | 0 | 0 |
| track_number | INTEGER | no | - | 0 | 0 |
| disc_number | INTEGER | no | - | 0 | 0 |
| bpm | REAL | no | - | 0 | 0 |
| key_signature | TEXT | no | - | 0 | 0 |
| comment | TEXT | no | - | 0 | 0 |
| duration | REAL | no | - | 0 | 0 |
| bitrate | INTEGER | no | - | 0 | 0 |
| sample_rate | INTEGER | no | - | 0 | 0 |
| channel_count | INTEGER | no | - | 0 | 0 |
| metadata_updated_at | TEXT | yes | - | 0 | 0 |

### Foreign Keys

| Id | Seq | From | Target Table | Target Column | On Update | On Delete | Match |
| ---: | ---: | --- | --- | --- | --- | --- | --- |
| 0 | 0 | track_id | tracks | id | NO ACTION | CASCADE | NONE |

### Indexes

| Name | Unique | Origin | Partial | Columns |
| --- | --- | --- | --- | --- |
| idx_track_metadata_album | no | c | no | album |
| idx_track_metadata_artist | no | c | no | artist |
| idx_track_metadata_duration | no | c | no | duration |
| idx_track_metadata_title | no | c | no | title |
| sqlite_autoindex_track_metadata_1 | yes | pk | no | track_id |

## tracklist_tracks

### Columns

| Name | Type | Not Null | Default | Primary Key | Hidden |
| --- | --- | --- | --- | --- | --- |
| id | TEXT | no | - | 1 | 0 |
| tracklist_id | TEXT | yes | - | 0 | 0 |
| track_id | TEXT | yes | - | 0 | 0 |
| position | INTEGER | yes | - | 0 | 0 |
| source_snapshot | TEXT | yes | - | 0 | 0 |
| title_snapshot | TEXT | no | - | 0 | 0 |
| artist_snapshot | TEXT | no | - | 0 | 0 |
| album_snapshot | TEXT | no | - | 0 | 0 |
| duration_snapshot | REAL | no | - | 0 | 0 |
| file_name_snapshot | TEXT | no | - | 0 | 0 |
| asset_url_snapshot | TEXT | no | - | 0 | 0 |
| is_available_snapshot | INTEGER | yes | 1 | 0 | 0 |
| created_at | TEXT | yes | - | 0 | 0 |

### Foreign Keys

| Id | Seq | From | Target Table | Target Column | On Update | On Delete | Match |
| ---: | ---: | --- | --- | --- | --- | --- | --- |
| 0 | 0 | tracklist_id | tracklists | id | NO ACTION | CASCADE | NONE |

### Indexes

| Name | Unique | Origin | Partial | Columns |
| --- | --- | --- | --- | --- |
| idx_tracklist_tracks_position | no | c | no | position |
| idx_tracklist_tracks_track_id | no | c | no | track_id |
| idx_tracklist_tracks_tracklist_id | no | c | no | tracklist_id |
| idx_tracklist_tracks_unique_position | yes | c | no | tracklist_id, position |
| sqlite_autoindex_tracklist_tracks_1 | yes | pk | no | id |

## tracklists

### Columns

| Name | Type | Not Null | Default | Primary Key | Hidden |
| --- | --- | --- | --- | --- | --- |
| id | TEXT | no | - | 1 | 0 |
| name | TEXT | yes | - | 0 | 0 |
| created_at | TEXT | yes | - | 0 | 0 |
| updated_at | TEXT | yes | - | 0 | 0 |
| sort_order | INTEGER | no | - | 0 | 0 |
| is_deleted | INTEGER | yes | 0 | 0 | 0 |

### Foreign Keys

No foreign keys.

### Indexes

| Name | Unique | Origin | Partial | Columns |
| --- | --- | --- | --- | --- |
| idx_tracklists_created_at | no | c | no | created_at |
| idx_tracklists_is_deleted | no | c | no | is_deleted |
| idx_tracklists_sort_order | no | c | no | sort_order |
| sqlite_autoindex_tracklists_1 | yes | pk | no | id |

## tracks

### Columns

| Name | Type | Not Null | Default | Primary Key | Hidden |
| --- | --- | --- | --- | --- | --- |
| id | TEXT | no | - | 1 | 0 |
| source | TEXT | yes | - | 0 | 0 |
| folder_id | TEXT | no | - | 0 | 0 |
| root_folder_id | TEXT | no | - | 0 | 0 |
| file_name | TEXT | yes | - | 0 | 0 |
| relative_path | TEXT | no | - | 0 | 0 |
| file_extension | TEXT | no | - | 0 | 0 |
| file_size | INTEGER | no | - | 0 | 0 |
| file_date | TEXT | no | - | 0 | 0 |
| imported_at | TEXT | yes | - | 0 | 0 |
| updated_at | TEXT | yes | - | 0 | 0 |
| bookmark_base64 | TEXT | no | - | 0 | 0 |
| asset_url | TEXT | no | - | 0 | 0 |
| is_available | INTEGER | yes | 1 | 0 | 0 |
| is_deleted | INTEGER | yes | 0 | 0 | 0 |

### Foreign Keys

| Id | Seq | From | Target Table | Target Column | On Update | On Delete | Match |
| ---: | ---: | --- | --- | --- | --- | --- | --- |
| 0 | 0 | root_folder_id | folders | id | NO ACTION | CASCADE | NONE |
| 1 | 0 | folder_id | folders | id | NO ACTION | SET NULL | NONE |

### Indexes

| Name | Unique | Origin | Partial | Columns |
| --- | --- | --- | --- | --- |
| idx_tracks_file_date | no | c | no | file_date |
| idx_tracks_folder_id | no | c | no | folder_id |
| idx_tracks_imported_at | no | c | no | imported_at |
| idx_tracks_is_available | no | c | no | is_available |
| idx_tracks_root_folder_id | no | c | no | root_folder_id |
| idx_tracks_root_relative_path | no | c | no | root_folder_id, relative_path |
| idx_tracks_source | no | c | no | source |
| idx_tracks_unique_library_path | yes | c | yes | root_folder_id, relative_path |
| sqlite_autoindex_tracks_1 | yes | pk | no | id |
