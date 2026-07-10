//
//  LibraryCollectionRootItem.swift
//  TrackList
//
//  Строка корневого экрана режима "Треки".
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

// Описывает строки корневого экрана режима "Треки".
enum LibraryCollectionRootItem: Identifiable, Hashable {
    // Открывает полный список треков фонотеки.
    case allTracks
    // Открывает значения выбранной категории метаданных.
    case category(LibraryCollectionCategory)

    // Явный порядок строк корневого экрана режима "Треки".
    static let rootItems: [LibraryCollectionRootItem] = [
        .allTracks,
        .category(.artists),
        .category(.albums),
        .category(.genres),
        .category(.labels),
        .category(.years)
    ]

    // Стабильный идентификатор строки корневого экрана.
    var id: String {
        switch self {
        case .allTracks:
            return "allTracks"
        case .category(let category):
            return "category-\(category.rawValue)"
        }
    }

    // Название строки корневого экрана.
    var title: String {
        switch self {
        case .allTracks:
            return "Треки"
        case .category(let category):
            return category.title
        }
    }

    // Системная иконка строки корневого экрана.
    var systemImage: String {
        switch self {
        case .allTracks:
            return "music.note.list"
        case .category(let category):
            return category.systemImage
        }
    }
}
