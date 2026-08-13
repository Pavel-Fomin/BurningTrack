//
//  ExportFeatureActionHandler.swift
//  TrackList
//
//  Обработка typed-действий и Sheet Flow глобального экспорта.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Combine
import Foundation

/// Отделяет действия Export UI от состояния операции и от глобального SheetManager.
@MainActor
final class ExportFeatureActionHandler: ObservableObject, ExportActionHandling {

    /// Владеет состоянием долгоживущей операции без выполнения sheet-команд.
    private let progressViewModel: ExportProgressViewModel

    /// Выполняет только typed route подробностей через общий SheetManager lifecycle.
    private let detailsRouter: any ExportDetailsRouting

    /// Создаёт обработчик с state- и routing-зависимостями Export-feature.
    init(
        progressViewModel: ExportProgressViewModel,
        detailsRouter: any ExportDetailsRouting
    ) {
        self.progressViewModel = progressViewModel
        self.detailsRouter = detailsRouter
    }

    /// Выполняет пользовательские намерения и lifecycle-события без доступа View к SheetManager.
    func handle(_ action: ExportAction) {
        switch action {
        case .cancel:
            guard progressViewModel.cancelExport() else { return }
            dismissCurrentDetailsRoute()

        case .presentDetails:
            guard progressViewModel.progress != nil else { return }
            let route = detailsRouter.presentExportDetails()
            progressViewModel.detailsPresentationWasRequested(for: route)

        case .dismissDetails:
            dismissCurrentDetailsRoute()

        case .detailsDidDisappear(let route):
            // Lifecycle только синхронизирует feature-state и никогда не запускает dismiss повторно.
            progressViewModel.detailsDidDisappear(for: route)

        case .dismissCompleted:
            let detailsRoute = progressViewModel.detailsRoute
            guard progressViewModel.dismissCompletedExport() else { return }

            if let detailsRoute {
                detailsRouter.dismissExportDetails(detailsRoute)
            }
        }
    }

    /// Передаёт explicit dismiss только route, созданному текущей feature-сессией.
    private func dismissCurrentDetailsRoute() {
        guard let route = progressViewModel.detailsRoute else { return }
        detailsRouter.dismissExportDetails(route)
    }
}
