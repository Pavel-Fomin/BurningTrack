//
//  LibraryTrackListSource.swift
//  TrackList
//
//  Источник списка треков фонотеки.
//
//  Created by Pavel Fomin on 09.07.2026.
//

import Foundation

// Описывает, откуда загружать строки общего списка треков фонотеки.
enum LibraryTrackListSource: Hashable, Identifiable {
    /// Обычная папка фонотеки.
    case folder(folderId: UUID)
    /// Все треки фонотеки из режима корня "Треки".
    case allLibraryTracks
    /// Значение раздела коллекции, выбранное в режиме корня "Треки".
    case collectionValue(category: LibraryCollectionCategory, rawValue: String, artistKey: String?)

    /// Стабильный идентификатор источника для SwiftUI и отладочной диагностики.
    var id: String {
        switch self {
        case .folder(let folderId):
            return "folder:\(folderId.uuidString)"
        case .allLibraryTracks:
            return "library:all-tracks"
        case .collectionValue(let category, let rawValue, let artistKey):
            let normalizedValue = category.normalizedMetadataKey(for: rawValue)
            let normalizedArtist = artistKey.map { category.normalizedMetadataKey(for: $0) } ?? "none"
            return "collection:\(category.rawValue):\(normalizedValue):artist:\(normalizedArtist)"
        }
    }

    /// Раздел коллекции, если источник открыт из артиста, альбома, жанра, лейбла или года.
    var collectionCategory: LibraryCollectionCategory? {
        switch self {
        case let .collectionValue(category, _, _):
            return category
        case .folder,
             .allLibraryTracks:
            return nil
        }
    }

    /// Режимы сортировки треков, доступные для текущего источника списка.
    var availableTrackSortModes: [LibraryTrackSortMode] {
        guard let collectionCategory else {
            return LibraryTrackSortMode.allCases
        }

        switch collectionCategory {
        case .artists:
            return LibraryTrackSortMode.allCases.filter {
                $0 != .artistAsc && $0 != .artistDesc
            }
        case .albums:
            return LibraryTrackSortMode.allCases.filter {
                $0 != .albumAsc && $0 != .albumDesc
            }
        case .genres:
            return LibraryTrackSortMode.allCases.filter {
                $0 != .genreAsc && $0 != .genreDesc
            }
        case .labels:
            return LibraryTrackSortMode.allCases.filter {
                $0 != .labelAsc && $0 != .labelDesc
            }
        case .years:
            return LibraryTrackSortMode.allCases.filter {
                $0 != .yearDesc && $0 != .yearAsc
            }
        }
    }

    /// Относится ли источник к общему списку треков фонотеки.
    var isAllLibraryTracks: Bool {
        guard case .allLibraryTracks = self else { return false }
        return true
    }

    /// Относится ли источник к выбранному значению раздела музыкальной коллекции.
    var isCollectionValue: Bool {
        guard case .collectionValue = self else { return false }
        return true
    }

    /// Отображаемое имя дочерней папки для экспорта, если источник поддерживает экспорт.
    var exportFolderName: String? {
        switch self {
        case .allLibraryTracks:
            return "Треки"
        case .collectionValue(_, let rawValue, _):
            return rawValue
        case .folder:
            return nil
        }
    }

    /// Идентификатор папки, если источник связан с папочной веткой фонотеки.
    var folderId: UUID? {
        switch self {
        case .folder(let folderId):
            return folderId
        case .allLibraryTracks,
             .collectionValue:
            return nil
        }
    }

    /// Можно ли читать и сохранять режим сортировки как настройку конкретной папки.
    var canPersistFolderSortMode: Bool {
        switch self {
        case .folder:
            return true
        case .allLibraryTracks,
             .collectionValue:
            return false
        }
    }
}

extension LibraryTrackListSource {
    /// Возвращает источник, который можно сохранить как playback-контекст.
    var playbackContextSource: PlaybackContextSource {
        switch self {
        case .folder(let folderId):
            return .libraryFolder(id: folderId)
        case .allLibraryTracks:
            return .libraryRoot
        case let .collectionValue(category, rawValue, artistKey):
            return .libraryCollection(
                category: category,
                rawValue: rawValue,
                artistKey: artistKey
            )
        }
    }
}
