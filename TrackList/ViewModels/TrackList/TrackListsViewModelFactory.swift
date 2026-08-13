//
//  TrackListsViewModelFactory.swift
//  TrackList
//
//  Собирает production ViewModel master-flow списка треклистов.
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
    /// Снимок настроек нужен только для начального режима отображения master-списка.
    private let settingsManager: any SettingsManaging
    /// Презентер ошибок автоматической загрузки, подготовленный Composition Root.
    private let loadFailurePresenter: any TrackListsLoadFailurePresenting
    /// Источник событий изменения треклистов, подготовленный Composition Root.
    private let eventProvider: any TrackListsEventProviding
    /// Синхронизирует root-detail iPad с опубликованным master-снимком.
    private let navigationPruning: any TrackListsNavigationPruning

    /// Получает готовые production-зависимости и не разрешает singleton самостоятельно.
    init(
        trackListsManager: any TrackListsManaging,
        trackListManager: any TrackListManaging,
        settingsManager: any SettingsManaging,
        loadFailurePresenter: any TrackListsLoadFailurePresenting,
        eventProvider: any TrackListsEventProviding,
        navigationPruning: any TrackListsNavigationPruning
    ) {
        self.trackListsManager = trackListsManager
        self.trackListManager = trackListManager
        self.settingsManager = settingsManager
        self.loadFailurePresenter = loadFailurePresenter
        self.eventProvider = eventProvider
        self.navigationPruning = navigationPruning
    }

    /// Создаёт production ViewModel с узким loader-контрактом и реактивным invalidation-потоком.
    func make() -> TrackListsViewModel {
        TrackListsViewModel(
            loader: TrackListsLoader(
                trackListsManager: trackListsManager,
                trackListManager: trackListManager
            ),
            initialSortMode: settingsManager.settings.internalSettings.trackListsSortMode,
            loadFailurePresenter: loadFailurePresenter,
            eventProvider: eventProvider,
            navigationPruning: navigationPruning
        )
    }
}
