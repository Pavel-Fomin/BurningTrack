//
//  LibraryFoldersSortMode.swift
//  TrackList
//
//  Режимы сортировки прикреплённых папок фонотеки.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

// Описывает пользовательские режимы сортировки корневых папок фонотеки.
enum LibraryFoldersSortMode: String, CaseIterable {
    case createdAt
    case name

    /// Название пункта сортировки в меню.
    var title: String {
        switch self {
        case .createdAt:
            return "По дате"
        case .name:
            return "По названию"
        }
    }

    /// Подпись текущей сортировки под пунктом меню.
    var caption: String {
        switch self {
        case .createdAt:
            return "по дате"
        case .name:
            return "по названию"
        }
    }
}
