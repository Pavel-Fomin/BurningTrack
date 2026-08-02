//
//  TrackListApp.swift
//  TrackList
//
//  файл запуска SwiftUI-приложения
//  PlayerViewModel — управляет воспроизведением
//
//  Created by Pavel Fomin on 28.04.2025.
//


import SwiftUI

@main
struct TrackListApp: App {

    /// Единый presentation-маршрутизатор sheet-сценариев приложения.
    let sheetManager: SheetManager
    /// Единый презентер пользовательских сообщений приложения.
    let toastManager: ToastManager
    /// Единый координатор межэкранной навигации приложения.
    let navigationCoordinator: NavigationCoordinator
    /// Единый менеджер настроек приложения.
    let appSettingsManager: AppSettingsManager
    /// Единый менеджер фонотеки приложения.
    let musicLibraryManager: MusicLibraryManager
    let playerViewModel: PlayerViewModel
    /// Capability состояния «Избранного» для глобальных sheet-сценариев.
    let favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    /// Capability проверки занятости файла для глобальных файловых sheet-сценариев.
    let fileBusyChecker: any TrackFileBusyChecking
    /// Capability согласованного освобождения текущего файла.
    let playbackFileReleaser: any CurrentPlaybackFileReleasing
    /// Единый обработчик «Избранного» передаётся во все production-сценарии приложения.
    let favoriteTrackActionHandler: FavoriteTrackActionHandler
    /// Готовый обработчик переименования файлов сохраняется на весь жизненный цикл приложения.
    let renameActionHandler: TrackFileRenameActionHandler
    /// Готовая фабрика экранного flow плеера с явными production-зависимостями.
    let playerScreenViewModelFactory: PlayerScreenViewModelFactory
    /// Готовые фабрики feature фонотеки с явными production-зависимостями.
    let libraryFeatureDependencies: LibraryFeatureDependencies
    /// Готовая фабрика ViewModel поиска с явными production-зависимостями.
    let searchViewModelFactory: SearchViewModelFactory
    /// Готовые фабрики detail-flow одного треклиста с явными production-зависимостями.
    let trackListFeatureDependencies: TrackListFeatureDependencies
    /// Единый ActionHandler master-flow треклистов для tab- и sidebar-компоновок.
    let trackListsActionHandler: TrackListsActionHandler

    /// Глобальная ViewModel сохраняет экспорт при смене вкладок и закрытии picker-а.
    @StateObject private var exportProgressViewModel: ExportProgressViewModel
    /// Глобальная ViewModel сохраняет master-flow треклистов при смене корневой компоновки.
    @StateObject private var trackListsViewModel: TrackListsViewModel
    /// Глобальная ViewModel сохраняет состояние корневой навигации при смене компоновки.
    @StateObject private var navigationViewModel: MainNavigationViewModel
    
    init() {
        let appDatabase = AppDatabase.shared
        do {
            // Открываем постоянное SQLite-хранилище один раз при старте приложения.
            try appDatabase.open()
        } catch {
            // Инфраструктура БД критична для следующих фаз, поэтому ошибка должна быть заметна сразу.
            preconditionFailure("Не удалось подготовить SQLite-хранилище: \(error.localizedDescription)")
        }

        // Composition Root — единственное место разрешения application-wide production-singleton-ов.
        let sheetManager = SheetManager.shared
        let toastManager = ToastManager.shared
        let navigationCoordinator = NavigationCoordinator.shared
        let scenePhaseHandler = ScenePhaseHandler.shared
        let appSettingsManager = AppSettingsManager.shared
        let musicLibraryManager = MusicLibraryManager.shared
        let trackRegistry = TrackRegistry.shared
        let trackListBadgeIndex = TrackListBadgeIndex.shared
        let trackListManager = TrackListManager.shared
        let trackListsManager = TrackListsManager.shared
        let playlistManager = PlaylistManager.shared
        let commandExecutor = AppCommandExecutor.shared
        let sheetActionCoordinator = SheetActionCoordinator.shared
        let runtimeSnapshotStore = TrackRuntimeStore.shared
        let runtimeSnapshotBuilder = TrackRuntimeSnapshotBuilder.shared
        let exportManager = ExportManager.shared
        let viewControllerProvider = ApplicationViewControllerProvider()
        let trackShareActionHandler = TrackShareActionHandler(
            preparationService: TrackSharePreparationService(),
            viewControllerProvider: viewControllerProvider,
            toastPresenter: toastManager
        )
        let favoritesEventCenter = FavoritesEventCenter.shared
        let favoritesService = FavoritesService(
            trackListsManager: trackListsManager,
            trackListManager: trackListManager,
            favoritesEvents: favoritesEventCenter
        )
        let favoriteTrackActionHandler = FavoriteTrackActionHandler(
            favoritesService: favoritesService
        )
        let playerManager = PlayerManager()
        let playerVM = PlayerViewModel(
            playerManager: playerManager,
            toastPresenter: toastManager,
            playlistManager: playlistManager,
            isLibraryAccessRestored: {
                musicLibraryManager.isAccessRestored
            },
            favoritesService: favoritesService,
            favoriteActionHandler: favoriteTrackActionHandler,
            favoritesEvents: favoritesEventCenter
        )
        // Один production-экземпляр плеера передаётся feature только через их узкие capability.
        let playbackStateProvider: any PlaybackStateProviding = playerVM
        let playbackController: any TrackPlaybackControlling = playerVM
        let favoriteTrackIdsProvider: any FavoriteTrackIdsProviding = playerVM
        let playbackFileReleaser: any CurrentPlaybackFileReleasing = playerVM
        let fileBusyChecker: any TrackFileBusyChecking = playerManager
        let renameActionHandler = TrackFileRenameActionHandler(
            fileBusyChecker: fileBusyChecker,
            sheetManager: sheetManager,
            commandExecutor: commandExecutor,
            toastManager: toastManager,
            proposalBuilder: FileRenameProposalBuilder()
        )

        let trackCollectionNavigationHandler = TrackCollectionNavigationHandler(
            trackRegistry: trackRegistry,
            navigationCoordinator: navigationCoordinator
        )
        let playerFeatureDependencies = PlayerFeatureDependencies(
            sheetManager: sheetManager,
            playlistManager: playlistManager,
            appSettingsManager: appSettingsManager,
            commandExecutor: commandExecutor,
            toastManager: toastManager,
            sheetActionCoordinator: sheetActionCoordinator,
            collectionNavigationHandler: trackCollectionNavigationHandler,
            trackShareActionHandler: trackShareActionHandler,
            trackFileRenameActionHandler: renameActionHandler,
            trackRegistry: trackRegistry
        )
        let playerScreenViewModelFactory = PlayerScreenViewModelFactory(
            dependencies: playerFeatureDependencies
        )

        let summaryProvider: any TrackCollectionSummaryProviding
        do {
            // Один SQLite-провайдер статистики получает уже открытое application-wide хранилище.
            summaryProvider = try SQLiteTrackCollectionSummaryProvider(
                database: appDatabase
            )
        } catch {
            preconditionFailure("Не удалось подготовить SQLite-провайдер статистики: \(error)")
        }
        let trackListViewModelFactory = TrackListViewModelFactory(
            fileRenamer: renameActionHandler,
            trackListManager: trackListManager,
            trackListsManager: trackListsManager,
            toastPresenter: toastManager,
            commandExecutor: commandExecutor,
            eventProvider: NotificationTrackListEventProvider(),
            settingsManager: appSettingsManager,
            runtimeSnapshotProvider: runtimeSnapshotStore,
            runtimeSnapshotBuilder: runtimeSnapshotBuilder,
            summaryProvider: summaryProvider,
            trackRegistry: trackRegistry,
            playbackStateProvider: playbackStateProvider,
            favoriteTrackIdsProvider: favoriteTrackIdsProvider
        )
        let trackListActionHandlerFactory = TrackListFlowActionHandlerFactory(
            sheetManager: sheetManager,
            sheetActionCoordinator: sheetActionCoordinator,
            commandExecutor: commandExecutor,
            toastPresenter: toastManager,
            collectionNavigationHandler: trackCollectionNavigationHandler,
            trackShareActionHandler: trackShareActionHandler,
            viewControllerProvider: viewControllerProvider,
            playbackStateProvider: playbackStateProvider,
            playbackController: playbackController
        )
        let trackListFeatureDependencies = TrackListFeatureDependencies(
            viewModelFactory: trackListViewModelFactory,
            actionHandlerFactory: trackListActionHandlerFactory
        )

        let libraryFeatureDependencies = LibraryFeatureDependencies(
            screenViewModelFactory: LibraryScreenViewModelFactory(
                navigationCoordinator: navigationCoordinator,
                musicLibraryManager: musicLibraryManager,
                trackRegistry: trackRegistry,
                toastPresenter: toastManager,
                trackEventProvider: NotificationLibraryTrackEventProvider()
            ),
            masterViewModelFactory: LibraryMasterViewModelFactory(
                manager: musicLibraryManager,
                settingsManager: appSettingsManager,
                toastPresenter: toastManager,
                stateBuilder: LibraryMasterScreenStateBuilder()
            ),
            masterActionHandlerFactory: LibraryMasterActionHandlerFactory(
                manager: musicLibraryManager,
                navigationCoordinator: navigationCoordinator,
                toastPresenter: toastManager,
                playbackState: playbackStateProvider,
                playbackController: playbackController
            ),
            allTracksActionHandlerFactory: LibraryAllTracksActionHandlerFactory(
                viewControllerProvider: viewControllerProvider,
                toastPresenter: toastManager
            ),
            collectionTracksActionHandlerFactory: LibraryCollectionTracksActionHandlerFactory(
                viewControllerProvider: viewControllerProvider,
                toastPresenter: toastManager
            ),
            purchasedITunesActionHandlerFactory: PurchasedITunesMusicActionHandlerFactory(
                viewControllerProvider: viewControllerProvider,
                toastPresenter: toastManager
            ),
            folderViewModelFactory: LibraryFolderViewModelFactory(
                navigationCoordinator: navigationCoordinator,
                viewControllerProvider: viewControllerProvider,
                toastPresenter: toastManager,
                summaryProvider: summaryProvider,
                eventProvider: NotificationLibraryTrackEventProvider()
            ),
            playbackStateProvider: playbackStateProvider,
            playbackController: playbackController,
            favoriteTrackIdsProvider: favoriteTrackIdsProvider,
            fileBusyChecker: fileBusyChecker,
            trackFileRenameActionHandler: renameActionHandler
        )

        let searchViewModelFactory = SearchViewModelFactory(
            searchService: SearchService(
                trackRegistry: trackRegistry,
                trackListBadgeIndex: trackListBadgeIndex,
                trackListsManager: trackListsManager,
                trackListManager: trackListManager
            ),
            settingsManager: appSettingsManager,
            toastPresenter: toastManager,
            favoriteTrackIdsProvider: favoriteTrackIdsProvider,
            playbackStateProvider: playbackStateProvider,
            playbackController: playbackController,
            navigationCoordinator: navigationCoordinator,
            sheetManager: sheetManager,
            sheetActionCoordinator: sheetActionCoordinator,
            fileRenamer: renameActionHandler
        )

        let trackListsViewModel = TrackListsViewModelFactory(
            trackListsManager: trackListsManager,
            trackListManager: trackListManager,
            toastPresenter: toastManager,
            settingsManager: appSettingsManager,
            eventProvider: NotificationTrackListsEventProvider()
        ).make()
        let trackListsActionHandler = TrackListsActionHandlerFactory(
            presenter: sheetManager
        ).make(
            viewModel: trackListsViewModel
        )
        let navigationViewModel = MainNavigationViewModel(
            scenePhaseHandler: scenePhaseHandler
        )

        self.sheetManager = sheetManager
        self.toastManager = toastManager
        self.navigationCoordinator = navigationCoordinator
        self.appSettingsManager = appSettingsManager
        self.musicLibraryManager = musicLibraryManager
        self.playerViewModel = playerVM
        self.favoriteTrackIdsProvider = favoriteTrackIdsProvider
        self.fileBusyChecker = fileBusyChecker
        self.playbackFileReleaser = playbackFileReleaser
        self.favoriteTrackActionHandler = favoriteTrackActionHandler
        self.renameActionHandler = renameActionHandler
        self.playerScreenViewModelFactory = playerScreenViewModelFactory
        self.libraryFeatureDependencies = libraryFeatureDependencies
        self.searchViewModelFactory = searchViewModelFactory
        self.trackListFeatureDependencies = trackListFeatureDependencies
        self.trackListsActionHandler = trackListsActionHandler
        // Фабрика получает подготовленные production-зависимости и собирает только export feature.
        let exportFeatureFactory = ExportFeatureFactory(
            exporter: exportManager,
            toastPresenter: toastManager,
            detailsRouter: sheetManager
        )
        _exportProgressViewModel = StateObject(
            wrappedValue: exportFeatureFactory.makeExportProgressViewModel()
        )
        _trackListsViewModel = StateObject(
            wrappedValue: trackListsViewModel
        )
        _navigationViewModel = StateObject(
            wrappedValue: navigationViewModel
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                playerViewModel: playerViewModel,
                favoriteTrackIdsProvider: favoriteTrackIdsProvider,
                fileBusyChecker: fileBusyChecker,
                playbackFileReleaser: playbackFileReleaser,
                favoriteTrackActionHandler: favoriteTrackActionHandler,
                renameActionHandler: renameActionHandler,
                trackListsViewModel: trackListsViewModel,
                navigationViewModel: navigationViewModel,
                sheetManager: sheetManager,
                toastManager: toastManager,
                navigationCoordinator: navigationCoordinator,
                playerScreenViewModelFactory: playerScreenViewModelFactory,
                libraryFeatureDependencies: libraryFeatureDependencies,
                searchViewModelFactory: searchViewModelFactory,
                trackListFeatureDependencies: trackListFeatureDependencies,
                trackListsActionHandler: trackListsActionHandler
            )
            .environmentObject(sheetManager)
            .environmentObject(exportProgressViewModel)
        }
    }
}
