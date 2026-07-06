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

    /// Создаёт production ViewModel для списка треклистов.
    func make() -> TrackListsViewModel {
        TrackListsViewModel(
            trackListsManager: TrackListsManager.shared,
            trackListManager: TrackListManager.shared,
            toastPresenter: ToastManager.shared,
            settingsManager: AppSettingsManager.shared,
            eventProvider: NotificationTrackListsEventProvider()
        )
    }
}
