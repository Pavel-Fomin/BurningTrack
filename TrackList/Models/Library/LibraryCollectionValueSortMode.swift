//
//  LibraryCollectionValueSortMode.swift
//  TrackList
//
//  Режимы сортировки значений разделов музыкальной коллекции.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

/// Режим сортировки значений раздела музыкальной коллекции.
enum LibraryCollectionValueSortMode: String, CaseIterable, Identifiable, Hashable {
    /// Название по возрастанию.
    case titleAscending

    /// Название по убыванию.
    case titleDescending

    /// Год: сначала новые.
    case yearNewestFirst

    /// Год: сначала старые.
    case yearOldestFirst

    /// Артист по возрастанию.
    case artistAscending

    /// Артист по убыванию.
    case artistDescending

    /// Стабильный идентификатор режима.
    var id: Self {
        self
    }

    /// Текст пункта меню для выбранного направления сортировки.
    var menuTitle: String {
        switch self {
        case .titleAscending,
             .artistAscending:
            return "А–Я"
        case .titleDescending,
             .artistDescending:
            return "Я–А"
        case .yearNewestFirst:
            return "Сначала новые"
        case .yearOldestFirst:
            return "Сначала старые"
        }
    }

    /// Группа вложенного меню, в которой показывается режим.
    var menuGroup: MenuGroup {
        switch self {
        case .titleAscending,
             .titleDescending:
            return .title
        case .yearNewestFirst,
             .yearOldestFirst:
            return .year
        case .artistAscending,
             .artistDescending:
            return .artist
        }
    }

    /// Группа режимов сортировки для построения меню раздела.
    enum MenuGroup: String, Identifiable, Hashable {
        /// Сортировка по названию.
        case title
        /// Сортировка по году.
        case year
        /// Сортировка по артисту.
        case artist

        /// Стабильный идентификатор группы меню.
        var id: Self {
            self
        }

        /// Заголовок вложенного меню.
        var title: String {
            switch self {
            case .title:
                return "По названию"
            case .year:
                return "По году"
            case .artist:
                return "По артисту"
            }
        }
    }
}
