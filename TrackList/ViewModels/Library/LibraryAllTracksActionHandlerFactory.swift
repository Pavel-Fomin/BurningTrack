//
//  LibraryAllTracksActionHandlerFactory.swift
//  TrackList
//
//  Собирает обработчик действий общего списка треков фонотеки.
//
//  Created by Pavel Fomin on 20.07.2026.
//

import Foundation

/// Собирает production-зависимости обработчика экспорта общего списка треков.
@MainActor
struct LibraryAllTracksActionHandlerFactory {

    /// Создаёт обработчик действий для текущего глобального состояния экспорта.
    func make(
        exportProgressViewModel: ExportProgressViewModel
    ) -> LibraryAllTracksActionHandler {
        LibraryAllTracksActionHandler(
            exportProgressViewModel: exportProgressViewModel,
            viewControllerProvider: ApplicationViewControllerProvider(),
            toastPresenter: ToastManager.shared
        )
    }
}
