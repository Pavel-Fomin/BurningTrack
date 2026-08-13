//
//  ExportFeatureFactory.swift
//  TrackList
//
//  Сборка production-конфигурации функции экспорта.
//
//  Created by Pavel Fomin on 18.07.2026.
//

import Foundation

/// Собирает зависимости глобального состояния экспорта для production-приложения.
@MainActor
struct ExportFeatureFactory {

    /// Application-level фасад, который выбирает папку и запускает экспорт.
    private let exporter: any TrackExporting

    /// Единый получатель пользовательских сообщений экспортного сценария.
    private let toastPresenter: any ToastPresenting

    /// Маршрут открытия и закрытия подробностей экспорта.
    private let detailsRouter: any ExportDetailsRouting

    /// Создаёт фабрику с явно переданными production- или тестовыми зависимостями.
    init(
        exporter: any TrackExporting,
        toastPresenter: any ToastPresenting,
        detailsRouter: any ExportDetailsRouting
    ) {
        self.exporter = exporter
        self.toastPresenter = toastPresenter
        self.detailsRouter = detailsRouter
    }

    /// Собирает долгоживущее состояние и единственный обработчик typed-действий Export-feature.
    func makeFeature() -> ExportFeature {
        let operationActionHandler = ExportActionHandler(
            exporter: exporter,
            toastPresenter: toastPresenter
        )
        let coordinator = ExportOperationCoordinator(
            actionHandler: operationActionHandler,
            liveActivityManager: ProgressLiveActivityManager()
        )

        let progressViewModel = ExportProgressViewModel(
            coordinator: coordinator,
            toastPresenter: toastPresenter
        )
        let actionHandler = ExportFeatureActionHandler(
            progressViewModel: progressViewModel,
            detailsRouter: detailsRouter
        )
        let requestHandler = ExportRequestActionHandler(
            progressViewModel: progressViewModel,
            toastPresenter: toastPresenter
        )

        return ExportFeature(
            progressViewModel: progressViewModel,
            actionHandler: actionHandler,
            requestHandler: requestHandler
        )
    }
}

/// Сохраняет связанные объекты Export-feature вместе в Composition Root.
@MainActor
struct ExportFeature {

    /// Долгоживущее состояние операции, независимое от presentation sheet.
    let progressViewModel: ExportProgressViewModel

    /// Обрабатывает действия собственного UI и lifecycle-события Export-feature.
    let actionHandler: ExportFeatureActionHandler

    /// Принимает типизированные запросы запуска из других функций приложения.
    let requestHandler: any ExportRequestHandling
}
