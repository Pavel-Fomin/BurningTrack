//
//  SearchViewModelFactory.swift
//  TrackList
//
//  Фабрика ViewModel раздела поиска.
//  Created by Pavel Fomin on 07.07.2026.
//

import Foundation

@MainActor
enum SearchViewModelFactory {

    /// Собирает production-зависимости поиска без DI-контейнера.
    static func make() -> SearchViewModel {
        SearchViewModel(
            searchService: SearchService(),
            runtimeController: LibraryTrackRuntimeController(),
            settingsManager: AppSettingsManager.shared,
            toastPresenter: ToastManager.shared,
            presenter: SearchPresenter()
        )
    }
}
