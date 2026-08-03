//
//  LibraryFolderRouteClosureEvaluator.swift
//  TrackList
//
//  Определяет фактическое закрытие активного destination папки фонотеки.
//
//  Created by Pavel Fomin on 03.08.2026.
//

import Foundation

/// Отделяет технические пересчёты NavigationStack от реальной смены активной папки.
enum LibraryFolderRouteClosureEvaluator {

    /// Возвращает true только когда активная папка действительно перестала быть верхним destination.
    static func didCloseActiveFolder(
        from oldPath: [NavigationCoordinator.LibraryRoute],
        to newPath: [NavigationCoordinator.LibraryRoute]
    ) -> Bool {
        guard oldPath != newPath,
              let oldRoute = oldPath.last,
              case .folder = oldRoute
        else {
            return false
        }

        return newPath.last != oldRoute
    }
}
