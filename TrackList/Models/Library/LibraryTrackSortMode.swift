//
//  LibraryTrackSortMode.swift
//  TrackList
//
//  Режим сортировки треков внутри папки фонотеки.
//
//  Created by Pavel Fomin on 06.07.2026.
//

import Foundation

// Описывает доступные режимы сортировки треков фонотеки.
enum LibraryTrackSortMode: CaseIterable, Hashable, RawRepresentable {
    typealias RawValue = String

    case artistAsc
    case artistDesc
    case titleAsc
    case titleDesc
    case albumAsc
    case albumDesc
    case yearDesc
    case yearAsc
    case labelAsc
    case labelDesc
    case genreAsc
    case genreDesc
    case commentAsc
    case fileNameAsc
    case fileNameDesc
    case fileDateDesc
    case fileDateAsc

    static let allCases: [LibraryTrackSortMode] = [
        .artistAsc,
        .artistDesc,
        .titleAsc,
        .titleDesc,
        .albumAsc,
        .albumDesc,
        .yearDesc,
        .yearAsc,
        .labelAsc,
        .labelDesc,
        .genreAsc,
        .genreDesc,
        .commentAsc,
        .fileNameAsc,
        .fileNameDesc,
        .fileDateDesc,
        .fileDateAsc
    ]

    /// Читает сохранённое значение и поддерживает старые date-rawValue без миграции SQLite.
    init?(rawValue: String) {
        switch rawValue {
        case "artistAsc":
            self = .artistAsc
        case "artistDesc":
            self = .artistDesc
        case "titleAsc":
            self = .titleAsc
        case "titleDesc":
            self = .titleDesc
        case "albumAsc":
            self = .albumAsc
        case "albumDesc":
            self = .albumDesc
        case "yearDesc":
            self = .yearDesc
        case "yearAsc":
            self = .yearAsc
        case "labelAsc":
            self = .labelAsc
        case "labelDesc":
            self = .labelDesc
        case "genreAsc":
            self = .genreAsc
        case "genreDesc":
            self = .genreDesc
        case "commentAsc":
            self = .commentAsc
        case "fileNameAsc":
            self = .fileNameAsc
        case "fileNameDesc":
            self = .fileNameDesc
        case "fileDateDesc", "dateDesc":
            self = .fileDateDesc
        case "fileDateAsc", "dateAsc":
            self = .fileDateAsc
        default:
            return nil
        }
    }

    /// Значение, которое сохраняется в SQLite для режима сортировки треков фонотеки.
    var rawValue: String {
        switch self {
        case .artistAsc:
            return "artistAsc"
        case .artistDesc:
            return "artistDesc"
        case .titleAsc:
            return "titleAsc"
        case .titleDesc:
            return "titleDesc"
        case .albumAsc:
            return "albumAsc"
        case .albumDesc:
            return "albumDesc"
        case .yearDesc:
            return "yearDesc"
        case .yearAsc:
            return "yearAsc"
        case .labelAsc:
            return "labelAsc"
        case .labelDesc:
            return "labelDesc"
        case .genreAsc:
            return "genreAsc"
        case .genreDesc:
            return "genreDesc"
        case .commentAsc:
            return "commentAsc"
        case .fileNameAsc:
            return "fileNameAsc"
        case .fileNameDesc:
            return "fileNameDesc"
        case .fileDateDesc:
            return "fileDateDesc"
        case .fileDateAsc:
            return "fileDateAsc"
        }
    }

    /// Общий descriptor для TrackSorter.
    var descriptor: TrackSortDescriptor {
        switch self {
        case .artistAsc:
            return TrackSortDescriptor(field: .artist, direction: .ascending)
        case .artistDesc:
            return TrackSortDescriptor(field: .artist, direction: .descending)
        case .titleAsc:
            return TrackSortDescriptor(field: .title, direction: .ascending)
        case .titleDesc:
            return TrackSortDescriptor(field: .title, direction: .descending)
        case .albumAsc:
            return TrackSortDescriptor(field: .album, direction: .ascending)
        case .albumDesc:
            return TrackSortDescriptor(field: .album, direction: .descending)
        case .yearDesc:
            return TrackSortDescriptor(field: .year, direction: .descending)
        case .yearAsc:
            return TrackSortDescriptor(field: .year, direction: .ascending)
        case .labelAsc:
            return TrackSortDescriptor(field: .label, direction: .ascending)
        case .labelDesc:
            return TrackSortDescriptor(field: .label, direction: .descending)
        case .genreAsc:
            return TrackSortDescriptor(field: .genre, direction: .ascending)
        case .genreDesc:
            return TrackSortDescriptor(field: .genre, direction: .descending)
        case .commentAsc:
            return TrackSortDescriptor(field: .comment, direction: .ascending)
        case .fileNameAsc:
            return TrackSortDescriptor(field: .fileName, direction: .ascending)
        case .fileNameDesc:
            return TrackSortDescriptor(field: .fileName, direction: .descending)
        case .fileDateDesc:
            return TrackSortDescriptor(field: .date, direction: .descending)
        case .fileDateAsc:
            return TrackSortDescriptor(field: .date, direction: .ascending)
        }
    }

    /// Date-секции сохраняются только для сортировки по дате.
    var usesDateSections: Bool {
        switch self {
        case .fileDateDesc, .fileDateAsc:
            return true
        case .artistAsc, .artistDesc,
             .titleAsc, .titleDesc,
             .albumAsc, .albumDesc,
             .yearDesc, .yearAsc,
             .labelAsc, .labelDesc,
             .genreAsc, .genreDesc,
             .commentAsc,
             .fileNameAsc, .fileNameDesc:
            return false
        }
    }

    /// Metadata-поля требуют сохранённых SQLite metadata для ключа сортировки.
    var requiresCachedMetadata: Bool {
        switch self {
        case .artistAsc, .artistDesc,
             .titleAsc, .titleDesc,
             .albumAsc, .albumDesc,
             .yearDesc, .yearAsc,
             .labelAsc, .labelDesc,
             .genreAsc, .genreDesc,
             .commentAsc:
            return true
        case .fileNameAsc, .fileNameDesc, .fileDateDesc, .fileDateAsc:
            return false
        }
    }
}
