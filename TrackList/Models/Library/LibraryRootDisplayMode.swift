//
//  LibraryRootDisplayMode.swift
//  TrackList
//
//  Режим отображения корня фонотеки.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

// Описывает режим корня фонотеки без привязки к конкретному экрану.
// Стабильное строковое значение используется при сохранении режима в SQLite.
enum LibraryRootDisplayMode: String, CaseIterable, Hashable, Identifiable {
    /// Текущий режим со списком источников и прикреплённых папок.
    case folders
    /// Новый режим со списком разделов музыкальной коллекции.
    case tracks

    /// Стабильный идентификатор для SwiftUI-списков.
    var id: Self {
        self
    }

    /// Название режима в сегментированном переключателе.
    var title: String {
        switch self {
        case .folders:
            return "Папки"
        case .tracks:
            return "Треки"
        }
    }

    /// Иконка toolbar-кнопки для текущего режима корня.
    var systemImage: String {
        switch self {
        case .folders:
            return "folder.fill"
        case .tracks:
            return "list.dash.header.rectangle.fill"
        }
    }

    /// Следующий режим, который включается по нажатию на toolbar-кнопку.
    var toggled: Self {
        switch self {
        case .folders:
            return .tracks
        case .tracks:
            return .folders
        }
    }
}
