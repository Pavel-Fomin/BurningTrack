//
//  PurchasedITunesMusicActionHandlerFactory.swift
//  TrackList
//
//  Сборка обработчика действий экрана «Куплено в iTunes».
//
//  Created by Pavel Fomin on 23.07.2026.
//

import Foundation

/// Собирает production-зависимости экранного действия экспорта iTunes.
@MainActor
struct PurchasedITunesMusicActionHandlerFactory {

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

    /// Создаёт обработчик для существующего глобального состояния экспорта.
    func make(
        exportProgressViewModel: ExportProgressViewModel
    ) -> PurchasedITunesMusicActionHandler {
        PurchasedITunesMusicActionHandler(
            exportProgressViewModel: exportProgressViewModel,
            viewControllerProvider: viewControllerProvider,
            toastPresenter: toastPresenter
        )
    }
}
