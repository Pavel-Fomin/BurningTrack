//
//  SearchSortMode.swift
//  TrackList
//
//  Модель режимов сортировки результатов поиска.
//  Created by Pavel Fomin on 08.07.2026.
//

import Foundation

// Группа нужна только для визуального разбиения меню сортировки на категории.
enum SearchSortModeGroupKind: String, CaseIterable {
    case artist
    case title
    case album
    case year
    case label
    case genre
    case comment
    case fileName
    case date
}

struct SearchSortModeGroup: Identifiable, Equatable {
    let kind: SearchSortModeGroupKind
    let modes: [SearchSortMode]

    /// Стабильный id нужен SwiftUI Menu для корректного ForEach.
    var id: String {
        kind.rawValue
    }
}

// Описывает режимы сортировки, доступные в поиске.
enum SearchSortMode: String, CaseIterable, Identifiable, Equatable {
    case artistAsc
    case artistDesc
    case titleAsc
    case titleDesc
    case albumAsc
    case albumDesc
    case yearNewest
    case yearOldest
    case labelAsc
    case labelDesc
    case genreAsc
    case genreDesc
    case commentAsc
    case filenameAsc
    case filenameDesc
    case dateNewest
    case dateOldest

    /// Стабильный id нужен SwiftUI Menu для корректного ForEach.
    var id: String {
        rawValue
    }

}

extension SearchSortMode {
    private static let artistModeGroup = SearchSortModeGroup(
        kind: .artist,
        modes: [.artistAsc, .artistDesc]
    )
    private static let titleModeGroup = SearchSortModeGroup(
        kind: .title,
        modes: [.titleAsc, .titleDesc]
    )
    private static let albumModeGroup = SearchSortModeGroup(
        kind: .album,
        modes: [.albumAsc, .albumDesc]
    )
    private static let yearModeGroup = SearchSortModeGroup(
        kind: .year,
        modes: [.yearNewest, .yearOldest]
    )
    private static let labelModeGroup = SearchSortModeGroup(
        kind: .label,
        modes: [.labelAsc, .labelDesc]
    )
    private static let genreModeGroup = SearchSortModeGroup(
        kind: .genre,
        modes: [.genreAsc, .genreDesc]
    )
    private static let commentModeGroup = SearchSortModeGroup(
        kind: .comment,
        modes: [.commentAsc]
    )
    private static let fileNameModeGroup = SearchSortModeGroup(
        kind: .fileName,
        modes: [.filenameAsc, .filenameDesc]
    )
    private static let dateModeGroup = SearchSortModeGroup(
        kind: .date,
        modes: [.dateNewest, .dateOldest]
    )

    /// Группы повторяют структуру сортировки фонотеки для меню поиска.
    static let allModeGroups: [SearchSortModeGroup] = [
        artistModeGroup,
        titleModeGroup,
        albumModeGroup,
        yearModeGroup,
        labelModeGroup,
        genreModeGroup,
        commentModeGroup,
        fileNameModeGroup,
        dateModeGroup
    ]

    /// Возвращает группы режимов, доступные для выбранного чипа поиска.
    static func availableModeGroups(
        for filter: TrackSearchMatchField?
    ) -> [SearchSortModeGroup] {
        switch filter {
        case .none:
            return allModeGroups

        case .some(.tag(.title)):
            return [titleModeGroup]

        case .some(.tag(.artist)):
            return [artistModeGroup]

        case .some(.tag(.album)):
            return [albumModeGroup]

        case .some(.tag(.year)):
            return [yearModeGroup]

        case .some(.tag(.publisher)):
            return [labelModeGroup]

        case .some(.tag(.genre)):
            return [genreModeGroup]

        case .some(.tag(.comment)):
            return [commentModeGroup]

        case .some(.fileName):
            return [fileNameModeGroup]
        }
    }

    /// Возвращает набор режимов, который соответствует выбранному чипу поиска.
    static func availableModes(
        for filter: TrackSearchMatchField?
    ) -> [SearchSortMode] {
        availableModeGroups(for: filter).flatMap(\.modes)
    }
}
