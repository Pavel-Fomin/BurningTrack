//
//  SearchFeatureFactory.swift
//  TrackList
//
//  Фабрика feature Search.
//  Created by Pavel Fomin on 07.07.2026.
//

import Foundation

@MainActor
struct SearchFeatureFactory {

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
    /// Общий обработчик переименования файла, подготовленный Composition Root.
    private let fileRenamer: TrackFileRenameActionHandler
    /// Общий обработчик «Избранного», подготовленный Composition Root.
    private let favoriteActionHandler: FavoriteTrackActionHandler
    /// Общий обработчик шаринга, подготовленный Composition Root.
    private let trackShareActionHandler: TrackShareActionHandler
    /// Общий исполнитель команд приложения, подготовленный Composition Root.
    private let commandExecutor: AppCommandExecutor
    /// Презентер результатов общих команд, подготовленный Composition Root.
    private let commandToastPresenter: AppCommandToastPresenter

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
        fileRenamer: TrackFileRenameActionHandler,
        favoriteActionHandler: FavoriteTrackActionHandler,
        trackShareActionHandler: TrackShareActionHandler,
        commandExecutor: AppCommandExecutor,
        commandToastPresenter: AppCommandToastPresenter
    ) {
        self.searchService = searchService
        self.settingsManager = settingsManager
        self.toastPresenter = toastPresenter
        self.favoriteTrackIdsProvider = favoriteTrackIdsProvider
        self.playbackStateProvider = playbackStateProvider
        self.playbackController = playbackController
        self.navigationCoordinator = navigationCoordinator
        self.sheetManager = sheetManager
        self.fileRenamer = fileRenamer
        self.favoriteActionHandler = favoriteActionHandler
        self.trackShareActionHandler = trackShareActionHandler
        self.commandExecutor = commandExecutor
        self.commandToastPresenter = commandToastPresenter
    }

    /// Собирает единый граф состояния и действий Search без доступа к глобальному графу зависимостей.
    func makeScreenStore() -> SearchScreenStore {
        let viewModel = SearchViewModel(
            searchService: searchService,
            runtimeController: LibraryTrackRuntimeController(),
            settingsManager: settingsManager,
            favoriteTrackIdsProvider: favoriteTrackIdsProvider,
            playbackStateProvider: playbackStateProvider,
            toastPresenter: toastPresenter,
            presenter: SearchPresenter()
        )

        let actionHandler = SearchActionHandler(
            viewModel: viewModel,
            playbackStateProvider: playbackStateProvider,
            playbackController: playbackController,
            navigationCoordinator: navigationCoordinator,
            sheetManager: sheetManager,
            fileRenamer: fileRenamer,
            favoriteActionHandler: favoriteActionHandler,
            trackShareActionHandler: trackShareActionHandler,
            commandExecutor: commandExecutor,
            commandToastPresenter: commandToastPresenter,
            toastPresenter: toastPresenter
        )

        return SearchScreenStore(
            viewModel: viewModel,
            actionHandler: actionHandler
        )
    }
}
