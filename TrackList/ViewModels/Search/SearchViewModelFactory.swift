//
//  SearchViewModelFactory.swift
//  TrackList
//
//  Фабрика ViewModel раздела поиска.
//  Created by Pavel Fomin on 07.07.2026.
//

import Foundation

@MainActor
struct SearchViewModelFactory {

    /// Доменный сервис поиска, подготовленный Composition Root.
    private let searchService: any SearchServicing
    /// Настройки отображения результатов, подготовленные Composition Root.
    private let settingsManager: any SettingsManaging
    /// Презентер ошибок поиска, подготовленный Composition Root.
    private let toastPresenter: any ToastPresenting
    /// Published-состояние «Избранного», подготовленное Composition Root.
    private let favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    /// Реактивное playback-состояние, подготовленное Composition Root.
    private let playbackStateProvider: any PlaybackStateProviding
    /// Команды запуска и toggle, подготовленные Composition Root.
    private let playbackController: any TrackPlaybackControlling
    /// Координатор навигации, подготовленный Composition Root.
    private let navigationCoordinator: NavigationCoordinator
    /// Менеджер sheet-состояния, подготовленный Composition Root.
    private let sheetManager: SheetManager
    /// Координатор sheet-действий, подготовленный Composition Root.
    private let sheetActionCoordinator: SheetActionCoordinator
    /// Общий обработчик переименования файла, подготовленный Composition Root.
    private let fileRenamer: TrackFileRenameActionHandler

    /// Получает готовые production-зависимости и не разрешает singleton самостоятельно.
    init(
        searchService: any SearchServicing,
        settingsManager: any SettingsManaging,
        toastPresenter: any ToastPresenting,
        favoriteTrackIdsProvider: any FavoriteTrackIdsProviding,
        playbackStateProvider: any PlaybackStateProviding,
        playbackController: any TrackPlaybackControlling,
        navigationCoordinator: NavigationCoordinator,
        sheetManager: SheetManager,
        sheetActionCoordinator: SheetActionCoordinator,
        fileRenamer: TrackFileRenameActionHandler
    ) {
        self.searchService = searchService
        self.settingsManager = settingsManager
        self.toastPresenter = toastPresenter
        self.favoriteTrackIdsProvider = favoriteTrackIdsProvider
        self.playbackStateProvider = playbackStateProvider
        self.playbackController = playbackController
        self.navigationCoordinator = navigationCoordinator
        self.sheetManager = sheetManager
        self.sheetActionCoordinator = sheetActionCoordinator
        self.fileRenamer = fileRenamer
    }

    /// Собирает ViewModel без доступа к глобальному графу зависимостей.
    func make() -> SearchViewModel {
        SearchViewModel(
            searchService: searchService,
            runtimeController: LibraryTrackRuntimeController(),
            settingsManager: settingsManager,
            favoriteTrackIdsProvider: favoriteTrackIdsProvider,
            playbackStateProvider: playbackStateProvider,
            toastPresenter: toastPresenter,
            presenter: SearchPresenter()
        )
    }

    /// Собирает ActionHandler поиска с теми же capability production-экземпляра плеера.
    func makeActionHandler(
        viewModel: SearchViewModel,
        favoriteActionHandler: FavoriteTrackActionHandler
    ) -> SearchActionHandler {
        SearchActionHandler(
            viewModel: viewModel,
            playbackStateProvider: playbackStateProvider,
            playbackController: playbackController,
            navigationCoordinator: navigationCoordinator,
            sheetManager: sheetManager,
            sheetActionCoordinator: sheetActionCoordinator,
            fileRenamer: fileRenamer,
            favoriteActionHandler: favoriteActionHandler
        )
    }
}
