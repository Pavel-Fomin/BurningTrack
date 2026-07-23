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

    /// Создаёт обработчик для существующего глобального состояния экспорта.
    func make(
        exportProgressViewModel: ExportProgressViewModel
    ) -> PurchasedITunesMusicActionHandler {
        PurchasedITunesMusicActionHandler(
            exportProgressViewModel: exportProgressViewModel,
            viewControllerProvider: ApplicationViewControllerProvider(),
            toastPresenter: ToastManager.shared
        )
    }
}
