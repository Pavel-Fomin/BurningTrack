//
//  LibraryCollectionRootItem.swift
//  TrackList
//
//  Строка корневого экрана режима "Треки".
//
//  Created by Pavel Fomin on 10.07.2026.
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

/// Готовое состояние строки корневого экрана режима "Треки".
/// Nil означает, что счётчик ещё не загружен, а не отсутствие значения.
struct LibraryCollectionRootItemState: Identifiable, Equatable {
    /// Описание строки и действие, которое она открывает.
    let item: LibraryCollectionRootItem
    /// Количество строк, которые пользователь увидит после перехода.
    let count: Int?

    /// Стабильный идентификатор строки для SwiftUI-списка.
    var id: String {
        item.id
    }
}
