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

    /// Провайдер системного контроллера, подготовленный Composition Root.
    private let viewControllerProvider: any ViewControllerProviding
    /// Презентер пользовательских сообщений, подготовленный Composition Root.
    private let toastPresenter: any ToastPresenting

    /// Получает готовые production-зависимости и не разрешает singleton самостоятельно.
    init(
        viewControllerProvider: any ViewControllerProviding,
        toastPresenter: any ToastPresenting
    ) {
        self.viewControllerProvider = viewControllerProvider
        self.toastPresenter = toastPresenter
    }

    /// Создаёт обработчик для типизированного источника текущего списка и глобального экспорта.
    func make(
        source: LibraryTrackListSource,
        exportProgressViewModel: ExportProgressViewModel
    ) -> LibraryCollectionTracksActionHandler {
        LibraryCollectionTracksActionHandler(
            source: source,
            exportProgressViewModel: exportProgressViewModel,
            viewControllerProvider: viewControllerProvider,
            toastPresenter: toastPresenter
        )
    }
}
