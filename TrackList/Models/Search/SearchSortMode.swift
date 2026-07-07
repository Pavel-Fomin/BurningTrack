//
//  SearchSortMode.swift
//  TrackList
//
//  Модель режимов сортировки результатов поиска.
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

// Группа нужна только для визуального разбиения меню "Все" на категории.
struct SearchSortModeGroup: Identifiable, Equatable {
    let id: String
    let title: String
    let modes: [SearchSortMode]
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

    /// Название пункта в меню сортировки поиска.
    var title: String {
        switch self {
        case .artistAsc:
            return "Артист А–Я"
        case .artistDesc:
            return "Артист Я–А"
        case .titleAsc:
            return "Название А–Я"
        case .titleDesc:
            return "Название Я–А"
        case .albumAsc:
            return "Альбом А–Я"
        case .albumDesc:
            return "Альбом Я–А"
        case .yearNewest:
            return "Год: сначала новые"
        case .yearOldest:
            return "Год: сначала старые"
        case .labelAsc:
            return "Лейбл А–Я"
        case .labelDesc:
            return "Лейбл Я–А"
        case .genreAsc:
            return "Жанр А–Я"
        case .genreDesc:
            return "Жанр Я–А"
        case .commentAsc:
            return "Комментарий"
        case .filenameAsc:
            return "Название файла А–Я"
        case .filenameDesc:
            return "Название файла Я–А"
        case .dateNewest:
            return "Дата: сначала новые"
        case .dateOldest:
            return "Дата: сначала старые"
        }
    }

    /// Короткая подпись используется внутри сгруппированного меню "Все".
    var groupedTitle: String {
        switch self {
        case .artistAsc,
             .titleAsc,
             .albumAsc,
             .labelAsc,
             .genreAsc,
             .filenameAsc:
            return "А–Я"
        case .artistDesc,
             .titleDesc,
             .albumDesc,
             .labelDesc,
             .genreDesc,
             .filenameDesc:
            return "Я–А"
        case .commentAsc:
            return "Комментарий"
        case .yearNewest,
             .dateNewest:
            return "Сначала новые"
        case .yearOldest,
             .dateOldest:
            return "Сначала старые"
        }
    }
}

extension SearchSortMode {
    private static let artistModeGroup = SearchSortModeGroup(
        id: "artist",
        title: "Артист",
        modes: [.artistAsc, .artistDesc]
    )
    private static let titleModeGroup = SearchSortModeGroup(
        id: "title",
        title: "Название",
        modes: [.titleAsc, .titleDesc]
    )
    private static let albumModeGroup = SearchSortModeGroup(
        id: "album",
        title: "Альбом",
        modes: [.albumAsc, .albumDesc]
    )
    private static let yearModeGroup = SearchSortModeGroup(
        id: "year",
        title: "Год",
        modes: [.yearNewest, .yearOldest]
    )
    private static let labelModeGroup = SearchSortModeGroup(
        id: "label",
        title: "Лейбл",
        modes: [.labelAsc, .labelDesc]
    )
    private static let genreModeGroup = SearchSortModeGroup(
        id: "genre",
        title: "Жанр",
        modes: [.genreAsc, .genreDesc]
    )
    private static let commentModeGroup = SearchSortModeGroup(
        id: "comment",
        title: "Комментарий",
        modes: [.commentAsc]
    )
    private static let fileNameModeGroup = SearchSortModeGroup(
        id: "filename",
        title: "Название файла",
        modes: [.filenameAsc, .filenameDesc]
    )
    private static let dateModeGroup = SearchSortModeGroup(
        id: "date",
        title: "Дата",
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
