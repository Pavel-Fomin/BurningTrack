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

    /// Создаёт обработчик действий для текущего глобального состояния экспорта.
    func make(
        exportProgressViewModel: ExportProgressViewModel
    ) -> LibraryAllTracksActionHandler {
        LibraryAllTracksActionHandler(
            exportProgressViewModel: exportProgressViewModel,
            viewControllerProvider: viewControllerProvider,
            toastPresenter: toastPresenter
        )
    }
}
