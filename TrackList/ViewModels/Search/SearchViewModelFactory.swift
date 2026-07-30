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
    static func make(
        favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    ) -> SearchViewModel {
        SearchViewModel(
            searchService: SearchService(),
            runtimeController: LibraryTrackRuntimeController(),
            settingsManager: AppSettingsManager.shared,
            favoriteTrackIdsProvider: favoriteTrackIdsProvider,
            toastPresenter: ToastManager.shared,
            presenter: SearchPresenter()
        )
    }
}
