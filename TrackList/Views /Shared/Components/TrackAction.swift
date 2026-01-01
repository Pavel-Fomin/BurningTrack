//
//  TrackAction.swift
//  TrackList
//
//  Глобальные действия над треками и их контекст использования
//
//  Created by Pavel Fomin on 15.09.2025.
//

import Foundation

/// Контекст, из которого вызывается действие над треком
enum TrackContext {
    case player      // Плеер
    case library     // Фонотека
    case tracklist   // Треклист
}

/// Возможные действия, которые можно выполнить с треком
enum TrackAction: Hashable {
    case showInLibrary     // Переход к треку в фонотеке
    case moveToFolder      // Переместить в другую папку
}

// MARK: - Правила доступности глобальных действий

extension TrackAction {

    /// Возвращает список глобальных действий,
    /// доступных для заданного контекста.
    static func available(for context: TrackContext) -> [TrackAction] {
        switch context {
        case .library:
            return [.moveToFolder]

        case .player:
            return [.showInLibrary, .moveToFolder]

        case .tracklist:
            return [.showInLibrary, .moveToFolder]
        }
    }
}
