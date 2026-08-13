//
//  TrackListsActionHandlerFactory.swift
//  TrackList
//
//  Собирает production ActionHandler master-flow треклистов.
//
//  Created by Pavel Fomin on 19.06.2026.
//

import Foundation

/// Собирает production action handler для master-flow списка треклистов.
@MainActor
struct TrackListsActionHandlerFactory {

    /// Менеджер master-списка, подготовленный Composition Root.
    private let trackListsManager: any TrackListsManaging
    /// Настройки master-flow, подготовленные Composition Root.
    private let settingsManager: any SettingsManaging
    /// Атомарное сохранение порядка и sort mode, подготовленное Composition Root.
    private let orderingStore: any TrackListsOrderingPersisting
    /// Презентер пользовательских ошибок, подготовленный Composition Root.
    private let toastPresenter: any ToastPresenting
    /// Презентер sheet-сценариев, подготовленный Composition Root.
    private let presenter: any TrackListsPresenting
    /// Одноразовые external-open запросы, подготовленные Composition Root.
    private let externalOpenRequests: any TrackListsExternalOpenRequestManaging

    /// Получает узкие production-зависимости и не разрешает singleton самостоятельно.
    init(
        trackListsManager: any TrackListsManaging,
        settingsManager: any SettingsManaging,
        orderingStore: any TrackListsOrderingPersisting,
        toastPresenter: any ToastPresenting,
        presenter: any TrackListsPresenting,
        externalOpenRequests: any TrackListsExternalOpenRequestManaging
    ) {
        self.trackListsManager = trackListsManager
        self.settingsManager = settingsManager
        self.orderingStore = orderingStore
        self.toastPresenter = toastPresenter
        self.presenter = presenter
        self.externalOpenRequests = externalOpenRequests
    }

    /// Создаёт production action handler для списка треклистов.
    func make(
        viewModel: TrackListsViewModel
    ) -> TrackListsActionHandler {
        TrackListsActionHandler(
            viewModel: viewModel,
            trackListsManager: trackListsManager,
            settingsManager: settingsManager,
            orderingStore: orderingStore,
            toastPresenter: toastPresenter,
            presenter: presenter,
            externalOpenRequests: externalOpenRequests
        )
    }
}
