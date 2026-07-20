//
//  LibraryCollectionTracksActionHandlerFactory.swift
//  TrackList
//
//  Собирает обработчик экспорта треков выбранного значения коллекции.
//
//  Created by Pavel Fomin on 20.07.2026.
//

import Foundation

/// Собирает production-зависимости обработчика экспорта выбранного значения коллекции.
@MainActor
struct LibraryCollectionTracksActionHandlerFactory {

    /// Создаёт обработчик для типизированного источника текущего списка и глобального экспорта.
    func make(
        source: LibraryTrackListSource,
        exportProgressViewModel: ExportProgressViewModel
    ) -> LibraryCollectionTracksActionHandler {
        LibraryCollectionTracksActionHandler(
            source: source,
            exportProgressViewModel: exportProgressViewModel,
            viewControllerProvider: ApplicationViewControllerProvider(),
            toastPresenter: ToastManager.shared
        )
    }
}
