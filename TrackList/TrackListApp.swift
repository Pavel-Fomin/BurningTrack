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
    /// Capability проверки занятости файла для глобальных файловых sheet-сценариев.
    let fileBusyChecker: any TrackFileBusyChecking
    /// Capability согласованного освобождения текущего файла.
    let playbackFileReleaser: any CurrentPlaybackFileReleasing
    /// Единый обработчик «Избранного» передаётся во все production-сценарии приложения.
    let favoriteTrackActionHandler: FavoriteTrackActionHandler
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
    /// Готовая factory связанного flow создания и выбора треклиста.
    let createTrackListFlowFactory: CreateTrackListFlowFactory
    /// Готовая factory feature-flow переименования треклиста.
    let renameTrackListFeatureFactory: RenameTrackListFeatureFactory
    /// Готовая factory feature-flow добавления треков в треклист.
    let addToTrackListFeatureFactory: AddToTrackListFeatureFactory
    /// Готовая factory feature-flow сохранения очереди плеера в треклист.
    let saveTrackListFeatureFactory: SaveTrackListFeatureFactory
    /// Готовая factory feature-flow ручного переименования файла трека.
    let renameTrackFileFeatureFactory: RenameTrackFileFeatureFactory
    /// Готовая factory feature-flow просмотра и редактирования одного трека.
    let trackDetailFeatureFactory: TrackDetailFeatureFactory
    /// Готовая factory feature-flow выбора папки и файловой операции.
    let moveToFolderFeatureFactory: MoveToFolderFeatureFactory
    /// Готовая factory feature-local массового редактирования тегов.
    let batchTagEditFeatureFactory: BatchTagEditFeatureFactory
    /// Готовая factory feature-local массового переименования файлов.
    let batchFilenameRenameFeatureFactory: BatchFilenameRenameFeatureFactory
    /// Единственный ActionHandler пользовательских действий и Sheet Flow Export-feature.
    let exportActionHandler: ExportFeatureActionHandler

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
        let cloudTrackAvailabilityManager = CloudTrackAvailabilityManager.shared
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

        let libraryTracksScreenFactory = LibraryTracksScreenFactory(
            tracksProvider: FastLibraryTracksProvider(),
            badgeProvider: DefaultTrackListBadgeProvider(),
            makeEventProvider: { NotificationLibraryTrackEventProvider() },
            settingsManager: appSettingsManager,
            trackRegistry: trackRegistry,
            musicLibraryManager: musicLibraryManager,
            playbackStateProvider: playbackStateProvider,
            playbackController: playbackController,
            favoriteTrackIdsProvider: favoriteTrackIdsProvider,
            renameActionHandler: renameActionHandler,
            favoriteTrackActionHandler: favoriteTrackActionHandler,
            sheetManager: sheetManager,
            cloudAvailabilityManager: cloudTrackAvailabilityManager,
            collectionNavigationHandler: trackCollectionNavigationHandler,
            trackShareActionHandler: trackShareActionHandler,
            commandExecutor: commandExecutor,
            toastManager: toastManager
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
            tracksScreenFactory: libraryTracksScreenFactory,
            playbackStateProvider: playbackStateProvider,
            playbackController: playbackController,
            favoriteTrackIdsProvider: favoriteTrackIdsProvider,
            trackFileRenameActionHandler: renameActionHandler,
            purchasedITunesTrackActionDependencies: PurchasedITunesTrackActionDependencies(
                sheetManager: sheetManager,
                commandExecutor: commandExecutor,
                toastPresenter: toastManager
            )
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
        let createTrackListFlowFactory = CreateTrackListFlowFactory(
            trackListsManager: trackListsManager,
            toastPresenter: toastManager,
            createRouter: sheetManager,
            selectionRouter: sheetManager,
            foldersProvider: musicLibraryManager,
            libraryTracksScreenFactory: libraryTracksScreenFactory,
            favoriteTrackIdsProvider: favoriteTrackIdsProvider
        )
        let renameTrackListFeatureFactory = RenameTrackListFeatureFactory(
            trackListsService: trackListsManager,
            toastPresenter: toastManager,
            router: sheetManager
        )
        let addToTrackListFeatureFactory = AddToTrackListFeatureFactory(
            trackListsService: trackListsManager,
            commandExecutor: commandExecutor,
            toastPresenter: toastManager,
            router: sheetManager
        )
        let saveTrackListFeatureFactory = SaveTrackListFeatureFactory(
            queueProvider: playlistManager,
            trackListsService: trackListsManager,
            toastPresenter: toastManager,
            router: sheetManager
        )
        let renameTrackFileFeatureFactory = RenameTrackFileFeatureFactory(
            fileBusyChecker: fileBusyChecker,
            playbackFileReleaser: playbackFileReleaser,
            commandExecutor: commandExecutor,
            toastPresenter: toastManager,
            router: sheetManager,
            proposalBuilder: FileRenameProposalBuilder()
        )
        let trackDetailFeatureFactory = TrackDetailFeatureFactory(
            snapshotProvider: runtimeSnapshotStore,
            snapshotBuilder: runtimeSnapshotBuilder,
            fileURLResolver: BookmarkTrackDetailFileURLResolver(),
            commandExecutor: commandExecutor,
            fileBusyChecker: fileBusyChecker,
            playbackFileReleaser: playbackFileReleaser,
            toastPresenter: toastManager,
            router: sheetManager,
            eventProvider: NotificationTrackDetailEventProvider()
        )
        let moveToFolderFeatureFactory = MoveToFolderFeatureFactory(
            trackRegistry: trackRegistry,
            library: musicLibraryManager,
            fileBusyChecker: fileBusyChecker,
            commandExecutor: commandExecutor,
            toastPresenter: toastManager,
            router: sheetManager
        )
        let batchTagEditFeatureFactory = BatchTagEditFeatureFactory(
            metadataLoader: BatchTagMetadataLoader(
                runtimeStore: runtimeSnapshotStore,
                snapshotBuilder: runtimeSnapshotBuilder
            ),
            saveExecutor: BatchTagEditSaveExecutor(
                appCommandExecutor: commandExecutor
            ),
            artworkDataProvider: runtimeSnapshotStore,
            artworkPreparer: BatchTagArtworkPreparer(),
            artworkCompressor: BatchTagArtworkCompressionService(),
            toastPresenter: toastManager,
            router: sheetManager
        )
        let batchFilenameRenameFeatureFactory = BatchFilenameRenameFeatureFactory(
            metadataLoader: BatchFilenameRenameMetadataLoader(
                runtimeStore: runtimeSnapshotStore,
                snapshotBuilder: runtimeSnapshotBuilder
            ),
            planBuilder: BatchFilenameRenamePlanBuilder(),
            commandExecutor: commandExecutor,
            fileBusyChecker: fileBusyChecker,
            router: sheetManager
        )

        self.sheetManager = sheetManager
        self.toastManager = toastManager
        self.navigationCoordinator = navigationCoordinator
        self.appSettingsManager = appSettingsManager
        self.musicLibraryManager = musicLibraryManager
        self.playerViewModel = playerVM
        self.fileBusyChecker = fileBusyChecker
        self.playbackFileReleaser = playbackFileReleaser
        self.favoriteTrackActionHandler = favoriteTrackActionHandler
        self.playerScreenViewModelFactory = playerScreenViewModelFactory
        self.libraryFeatureDependencies = libraryFeatureDependencies
        self.searchViewModelFactory = searchViewModelFactory
        self.trackListFeatureDependencies = trackListFeatureDependencies
        self.trackListsActionHandler = trackListsActionHandler
        self.createTrackListFlowFactory = createTrackListFlowFactory
        self.renameTrackListFeatureFactory = renameTrackListFeatureFactory
        self.addToTrackListFeatureFactory = addToTrackListFeatureFactory
        self.saveTrackListFeatureFactory = saveTrackListFeatureFactory
        self.renameTrackFileFeatureFactory = renameTrackFileFeatureFactory
        self.trackDetailFeatureFactory = trackDetailFeatureFactory
        self.moveToFolderFeatureFactory = moveToFolderFeatureFactory
        self.batchTagEditFeatureFactory = batchTagEditFeatureFactory
        self.batchFilenameRenameFeatureFactory = batchFilenameRenameFeatureFactory
        // Фабрика получает подготовленные production-зависимости и собирает только export feature.
        let exportFeatureFactory = ExportFeatureFactory(
            exporter: exportManager,
            toastPresenter: toastManager,
            detailsRouter: sheetManager
        )
        let exportFeature = exportFeatureFactory.makeFeature()
        exportActionHandler = exportFeature.actionHandler
        _exportProgressViewModel = StateObject(
            wrappedValue: exportFeature.progressViewModel
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
                fileBusyChecker: fileBusyChecker,
                playbackFileReleaser: playbackFileReleaser,
                favoriteTrackActionHandler: favoriteTrackActionHandler,
                trackListsViewModel: trackListsViewModel,
                navigationViewModel: navigationViewModel,
                sheetManager: sheetManager,
                toastManager: toastManager,
                navigationCoordinator: navigationCoordinator,
                playerScreenViewModelFactory: playerScreenViewModelFactory,
                libraryFeatureDependencies: libraryFeatureDependencies,
                searchViewModelFactory: searchViewModelFactory,
                trackListFeatureDependencies: trackListFeatureDependencies,
                trackListsActionHandler: trackListsActionHandler,
                createTrackListFlowFactory: createTrackListFlowFactory,
                renameTrackListFeatureFactory: renameTrackListFeatureFactory,
                addToTrackListFeatureFactory: addToTrackListFeatureFactory,
                saveTrackListFeatureFactory: saveTrackListFeatureFactory,
                renameTrackFileFeatureFactory: renameTrackFileFeatureFactory,
                trackDetailFeatureFactory: trackDetailFeatureFactory,
                moveToFolderFeatureFactory: moveToFolderFeatureFactory,
                batchTagEditFeatureFactory: batchTagEditFeatureFactory,
                batchFilenameRenameFeatureFactory: batchFilenameRenameFeatureFactory
            )
            .environmentObject(sheetManager)
            .environmentObject(exportProgressViewModel)
            .environmentObject(exportActionHandler)
        }
    }
}
