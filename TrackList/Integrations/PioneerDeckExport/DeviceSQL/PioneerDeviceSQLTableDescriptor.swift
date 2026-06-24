//
//  PioneerDeviceSQLTableDescriptor.swift
//  TrackList
//
//  Описание таблиц legacy DeviceSQL export.pdb.
//

import Foundation

/// Типы таблиц export.pdb, подтверждённые rekordbox_pdb.ksy.
public enum PioneerDeviceSQLTableType: UInt32, CaseIterable, Sendable {
    /// Метаданные треков.
    case tracks = 0

    /// Справочник жанров.
    case genres = 1

    /// Справочник артистов.
    case artists = 2

    /// Справочник альбомов.
    case albums = 3

    /// Справочник лейблов.
    case labels = 4

    /// Справочник музыкальных тональностей.
    case keys = 5

    /// Справочник цветовых меток.
    case colors = 6

    /// Дерево плейлистов и папок.
    case playlistTree = 7

    /// Строки плейлистов с порядком треков.
    case playlistEntries = 8

    /// Таблица type 9 из rekordbox_pdb.ksy, строки пока не реализованы.
    case unknown9 = 9

    /// Таблица type 10 из rekordbox_pdb.ksy, строки пока не реализованы.
    case unknown10 = 10

    /// Таблица type 11 из rekordbox_pdb.ksy, строки пока не реализованы.
    case unknown11 = 11

    /// Таблица type 12 из rekordbox_pdb.ksy, строки пока не реализованы.
    case unknown12 = 12

    /// Справочник artwork.
    case artwork = 13

    /// Таблица type 14 из rekordbox_pdb.ksy, строки пока не реализованы.
    case unknown14 = 14

    /// Таблица type 15 из rekordbox_pdb.ksy, строки пока не реализованы.
    case unknown15 = 15

    /// Настройки колонок браузера.
    case columns = 16

    /// История плейлистов.
    case historyPlaylists = 17

    /// Строки истории.
    case historyEntries = 18

    /// Справочник истории.
    case history = 19

    /// Человекочитаемое имя таблицы для readback-тестов.
    public var tableName: String {
        switch self {
        case .tracks:
            return "tracks"
        case .genres:
            return "genres"
        case .artists:
            return "artists"
        case .albums:
            return "albums"
        case .labels:
            return "labels"
        case .keys:
            return "keys"
        case .colors:
            return "colors"
        case .playlistTree:
            return "playlist_tree"
        case .playlistEntries:
            return "playlist_entries"
        case .unknown9:
            return "unknown_0x09"
        case .unknown10:
            return "unknown_0x0a"
        case .unknown11:
            return "unknown_0x0b"
        case .unknown12:
            return "unknown_0x0c"
        case .artwork:
            return "artwork"
        case .unknown14:
            return "unknown_0x0e"
        case .unknown15:
            return "unknown_0x0f"
        case .columns:
            return "columns"
        case .historyPlaylists:
            return "history_playlists"
        case .historyEntries:
            return "history_entries"
        case .history:
            return "history"
        }
    }
}

/// Table pointer из первой страницы DeviceSQL-файла.
struct PioneerDeviceSQLTableDescriptor: Equatable {
    /// Тип таблицы из enum page_type.
    let type: PioneerDeviceSQLTableType

    /// Candidate-страница для пустого/free page chain из table pointer.
    let emptyCandidate: UInt32

    /// Первая страница цепочки таблицы.
    let firstPage: UInt32

    /// Последняя страница цепочки таблицы.
    let lastPage: UInt32

    /// Количество строк известно writer-слою и используется только для readback-дампа.
    let rowCount: Int

    /// Создаёт table pointer для DeviceSQL header.
    init(
        type: PioneerDeviceSQLTableType,
        emptyCandidate: UInt32 = 0,
        firstPage: UInt32,
        lastPage: UInt32,
        rowCount: Int
    ) {
        self.type = type
        self.emptyCandidate = emptyCandidate
        self.firstPage = firstPage
        self.lastPage = lastPage
        self.rowCount = rowCount
    }
}
