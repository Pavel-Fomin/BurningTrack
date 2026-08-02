//
//  TrackListsViewModelFactory.swift
//  TrackList
//
//  Created by Pavel Fomin on 19.06.2026.
//

import Foundation

/// Собирает production ViewModel для master-flow списка треклистов.
@MainActor
struct TrackListsViewModelFactory {

    /// Менеджер метаданных списка треклистов, подготовленный Composition Root.
    private let trackListsManager: any TrackListsManaging
    /// Менеджер содержимого одного треклиста, подготовленный Composition Root.
    private let trackListManager: any TrackListManaging
    /// Презентер пользовательских сообщений, подготовленный Composition Root.
    private let toastPresenter: any ToastPresenting
    /// Настройки master-flow, подготовленные Composition Root.
    private let settingsManager: any SettingsManaging
    /// Источник событий изменения треклистов, подготовленный Composition Root.
    private let eventProvider: any TrackListsEventProviding

    /// Получает готовые production-зависимости и не разрешает singleton самостоятельно.
    init(
        trackListsManager: any TrackListsManaging,
        trackListManager: any TrackListManaging,
        toastPresenter: any ToastPresenting,
        settingsManager: any SettingsManaging,
        eventProvider: any TrackListsEventProviding
    ) {
        self.trackListsManager = trackListsManager
        self.trackListManager = trackListManager
        self.toastPresenter = toastPresenter
        self.settingsManager = settingsManager
        self.eventProvider = eventProvider
    }

    /// Создаёт production ViewModel для списка треклистов.
    func make() -> TrackListsViewModel {
        TrackListsViewModel(
            trackListsManager: trackListsManager,
            trackListManager: trackListManager,
            toastPresenter: toastPresenter,
            settingsManager: settingsManager,
            eventProvider: eventProvider
        )
    }
}
