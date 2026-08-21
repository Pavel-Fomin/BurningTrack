//
//  LibraryTracksScreenFactory.swift
//  TrackList
//
//  Точка сборки экранной возможности Library Tracks.
//
//  Created by Pavel Fomin on 02.08.2026.
//

import SwiftUI

/// Собирает варианты Library Tracks и удерживает production composition вне SwiftUI View.
@MainActor
struct LibraryTracksScreenFactory {
    private let tracksProvider: LibraryTracksProvider
    private let badgeProvider: TrackListBadgeProvider
    private let makeEventProvider: () -> any LibraryTrackEventProvider
    /// Общий runtime store передаётся из Composition Root всем destination фонотеки.
    private let runtimeSnapshotStore: any TrackRuntimeSnapshotStoring
    /// Один builder сохраняет каноничный путь загрузки metadata для controller-а.
    private let runtimeSnapshotBuilder: any TrackRuntimeSnapshotBuilding
    private let settingsManager: AppSettingsManager
    private let trackRegistry: TrackRegistry
    /// Screen-flow зависит только от capability синхронизации текущей папки.
    private let musicLibraryManager: any LibraryFolderSyncing
    private let playbackStateProvider: any PlaybackStateProviding
    private let playbackController: any TrackPlaybackControlling
    private let favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    private let renameActionHandler: TrackFileRenameActionHandler
    private let favoriteTrackActionHandler: FavoriteTrackActionHandler
    private let sheetManager: SheetManager
    private let cloudAvailabilityManager: any CloudTrackAvailabilityManaging
    private let collectionNavigationHandler: TrackCollectionNavigationHandler
    private let trackShareActionHandler: TrackShareActionHandler
    private let commandExecutor: AppCommandExecutor
    private let toastManager: ToastManager
    /// Создаёт handler экспорта общего раздела внутри graph его destination.
    private let allTracksActionHandlerFactory: LibraryAllTracksActionHandlerFactory
    /// Создаёт handler экспорта выбранного значения коллекции внутри graph destination.
    private let collectionTracksActionHandlerFactory: LibraryCollectionTracksActionHandlerFactory

    init(
        tracksProvider: LibraryTracksProvider,
        badgeProvider: TrackListBadgeProvider,
        makeEventProvider: @escaping () -> any LibraryTrackEventProvider,
        runtimeSnapshotStore: any TrackRuntimeSnapshotStoring,
        runtimeSnapshotBuilder: any TrackRuntimeSnapshotBuilding,
        settingsManager: AppSettingsManager,
        trackRegistry: TrackRegistry,
        musicLibraryManager: any LibraryFolderSyncing,
        playbackStateProvider: any PlaybackStateProviding,
        playbackController: any TrackPlaybackControlling,
        favoriteTrackIdsProvider: any FavoriteTrackIdsProviding,
        renameActionHandler: TrackFileRenameActionHandler,
        favoriteTrackActionHandler: FavoriteTrackActionHandler,
        sheetManager: SheetManager,
        cloudAvailabilityManager: any CloudTrackAvailabilityManaging,
        collectionNavigationHandler: TrackCollectionNavigationHandler,
        trackShareActionHandler: TrackShareActionHandler,
        commandExecutor: AppCommandExecutor,
        toastManager: ToastManager,
        allTracksActionHandlerFactory: LibraryAllTracksActionHandlerFactory,
        collectionTracksActionHandlerFactory: LibraryCollectionTracksActionHandlerFactory
    ) {
        self.tracksProvider = tracksProvider
        self.badgeProvider = badgeProvider
        self.makeEventProvider = makeEventProvider
        self.runtimeSnapshotStore = runtimeSnapshotStore
        self.runtimeSnapshotBuilder = runtimeSnapshotBuilder
        self.settingsManager = settingsManager
        self.trackRegistry = trackRegistry
        self.musicLibraryManager = musicLibraryManager
        self.playbackStateProvider = playbackStateProvider
        self.playbackController = playbackController
        self.favoriteTrackIdsProvider = favoriteTrackIdsProvider
        self.renameActionHandler = renameActionHandler
        self.favoriteTrackActionHandler = favoriteTrackActionHandler
        self.sheetManager = sheetManager
        self.cloudAvailabilityManager = cloudAvailabilityManager
        self.collectionNavigationHandler = collectionNavigationHandler
        self.trackShareActionHandler = trackShareActionHandler
        self.commandExecutor = commandExecutor
        self.toastManager = toastManager
        self.allTracksActionHandlerFactory = allTracksActionHandlerFactory
        self.collectionTracksActionHandlerFactory = collectionTracksActionHandlerFactory
    }

    /// Возвращает контейнер, который откладывает production composition до инициализации StateObject.
    func makeLibraryTracksContainer(
        folder: LibraryFolder,
        summary: TrackCollectionSummary?,
        subfolders: [LibraryFolder],
        revealRequest: LibraryRevealRequest?,
        onSubfolderTap: @escaping (LibraryFolder) -> Void,
        onExportTracks: @escaping ([LibraryTrack]) -> Void,
        onRevealHandled: @escaping (UUID) -> Void,
        selectionActionBarConfig: Binding<SelectionActionBarConfig?>,
        selectionActionSender: Binding<(any LibraryTracksActionSending)?>
    ) -> LibraryTracksContainer {
        LibraryTracksContainer(
            factory: self,
            folder: folder,
            summary: summary,
            subfolders: subfolders,
            revealRequest: revealRequest,
            onSubfolderTap: onSubfolderTap,
            onExportTracks: onExportTracks,
            onRevealHandled: onRevealHandled,
            selectionActionBarConfig: selectionActionBarConfig,
            selectionActionSender: selectionActionSender
        )
    }

    /// Возвращает контейнер списка общего раздела или выбранного значения коллекции.
    /// Стабильный source передаётся до создания StateObject, чтобы graph не переживал смену collection destination.
    func makeLibraryCollectionTracksContainer(
        source: LibraryTrackListSource,
        selectionActionBarConfig: Binding<SelectionActionBarConfig?>,
        selectionActionSender: Binding<(any LibraryTracksActionSending)?>
    ) -> LibraryCollectionTracksContainer {
        LibraryCollectionTracksContainer(
            factory: self,
            source: source,
            selectionActionBarConfig: selectionActionBarConfig,
            selectionActionSender: selectionActionSender
        )
    }

    /// Собирает ViewModel папки для selection-flow без создания production-зависимостей во View.
    func makeSelectionTracksViewModel(
        folder: LibraryFolder
    ) -> LibraryTracksViewModel {
        let viewModel = makeTracksViewModel(
            source: .folder(folderId: folder.id),
            usesLibrarySortSettings: false
        )
        let presenter = LibraryTracksPresenter(
            output: viewModel,
            selectionActionBarCoordinator: LibrarySelectionActionBarCoordinator()
        )
        let actionHandler = LibraryTracksActionHandler(output: viewModel)
        viewModel.configure(actionHandler: actionHandler, presenter: presenter)
        return viewModel
    }

    /// Собирает тонкий маршрутизатор Batch Tag Edit без глобальных singleton в Library ViewModel.
    func makeBatchTagEditHandler() -> LibraryBatchTagEditHandler {
        LibraryBatchTagEditHandler(router: sheetManager)
    }

    /// Собирает тонкий маршрутизатор Batch Filename Rename без singleton в Library ViewModel.
    func makeBatchRenameHandler() -> LibraryBatchRenameHandler {
        LibraryBatchRenameHandler(router: sheetManager)
    }

    /// Собирает graph один раз по запросу StateObject-контейнера, не из body родительского View.
    func makeScreenStore(
        folder: LibraryFolder,
        revealRequest: LibraryRevealRequest?
    ) -> LibraryTracksScreenStore {
        let viewModel = makeTracksViewModel(
            source: .folder(folderId: folder.id),
            usesLibrarySortSettings: true
        )
        let presenter = LibraryTracksPresenter(
            output: viewModel,
            selectionActionBarCoordinator: LibrarySelectionActionBarCoordinator()
        )
        let actionHandler = LibraryTracksActionHandler(output: viewModel)
        viewModel.configure(actionHandler: actionHandler, presenter: presenter)

        let cloudController = LibraryCloudAvailabilityScreenController(
            availabilityController: CloudTrackAvailabilityController(
                manager: cloudAvailabilityManager
            )
        )
        let cloudAvailabilityActionHandler = LibraryCloudAvailabilityActionHandler(
            controller: cloudController
        )
        let presentationHandler = LibraryTrackPresentationHandler(metadataProvider: viewModel)
        let commandHandler = LibraryTrackCommandHandler(
            sheetManager: sheetManager,
            playbackHandler: LibraryTrackPlaybackHandler(
                playbackStateProvider: playbackStateProvider,
                playbackController: playbackController,
                source: .libraryFolder(id: folder.id)
            ),
            presentationHandler: presentationHandler,
            cloudAvailabilityActionHandler: cloudAvailabilityActionHandler,
            collectionNavigationHandler: collectionNavigationHandler,
            trackShareActionHandler: trackShareActionHandler,
            commandExecutor: commandExecutor,
            toastManager: toastManager,
            favoriteActionHandler: favoriteTrackActionHandler,
            screenActionHandler: actionHandler,
            onRenameTrack: { [weak viewModel] trackId, strategy in
                viewModel?.renameTrack(trackId: trackId, strategy: strategy)
            }
        )

        return LibraryTracksScreenStore(
            tracksViewModel: viewModel,
            cloudAvailabilityController: cloudController,
            cloudAvailabilityActionHandler: cloudAvailabilityActionHandler,
            settingsManager: settingsManager,
            playbackStateController: LibraryTrackPlaybackStateController(
                playbackStateProvider: playbackStateProvider
            ),
            revealCoordinator: LibraryTrackRevealCoordinator(initialRequest: revealRequest),
            presentationHandler: presentationHandler,
            commandHandler: commandHandler,
            favoriteTrackIdsProvider: favoriteTrackIdsProvider
        )
    }

    /// Собирает screen-local graph списка общего раздела или значения коллекции один раз на destination.
    func makeCollectionScreenStore(
        source: LibraryTrackListSource
    ) -> LibraryCollectionTracksScreenStore {
        let viewModel = makeTracksViewModel(
            source: source,
            usesLibrarySortSettings: false
        )
        let presenter = LibraryTracksPresenter(
            output: viewModel,
            selectionActionBarCoordinator: LibrarySelectionActionBarCoordinator()
        )
        let actionHandler = LibraryTracksActionHandler(output: viewModel)
        viewModel.configure(actionHandler: actionHandler, presenter: presenter)

        let cloudController = LibraryCloudAvailabilityScreenController(
            availabilityController: CloudTrackAvailabilityController(
                manager: cloudAvailabilityManager
            )
        )
        let cloudAvailabilityActionHandler = LibraryCloudAvailabilityActionHandler(
            controller: cloudController
        )
        let presentationHandler = LibraryTrackPresentationHandler(metadataProvider: viewModel)
        let commandHandler = LibraryTrackCommandHandler(
            sheetManager: sheetManager,
            playbackHandler: LibraryTrackPlaybackHandler(
                playbackStateProvider: playbackStateProvider,
                playbackController: playbackController,
                source: source.playbackContextSource
            ),
            presentationHandler: presentationHandler,
            cloudAvailabilityActionHandler: cloudAvailabilityActionHandler,
            collectionNavigationHandler: collectionNavigationHandler,
            trackShareActionHandler: trackShareActionHandler,
            commandExecutor: commandExecutor,
            toastManager: toastManager,
            favoriteActionHandler: favoriteTrackActionHandler,
            screenActionHandler: actionHandler,
            onRenameTrack: { [weak viewModel] trackId, strategy in
                viewModel?.renameTrack(trackId: trackId, strategy: strategy)
            }
        )

        let allTracksActionHandler = source.isAllLibraryTracks
            ? allTracksActionHandlerFactory.make()
            : nil
        let collectionTracksActionHandler = source.isCollectionValue
            ? collectionTracksActionHandlerFactory.make(source: source)
            : nil

        return LibraryCollectionTracksScreenStore(
            source: source,
            tracksViewModel: viewModel,
            cloudAvailabilityController: cloudController,
            cloudAvailabilityActionHandler: cloudAvailabilityActionHandler,
            settingsManager: settingsManager,
            playbackStateController: LibraryTrackPlaybackStateController(
                playbackStateProvider: playbackStateProvider
            ),
            presentationHandler: presentationHandler,
            commandHandler: commandHandler,
            favoriteTrackIdsProvider: favoriteTrackIdsProvider,
            sheetManager: sheetManager,
            allTracksActionHandler: allTracksActionHandler,
            collectionTracksActionHandler: collectionTracksActionHandler
        )
    }

    /// Создаёт общую ViewModel списка, изолируя её production-зависимости внутри Library Tracks factory.
    private func makeTracksViewModel(
        source: LibraryTrackListSource,
        usesLibrarySortSettings: Bool
    ) -> LibraryTracksViewModel {
        LibraryTracksViewModel(
            source: source,
            renameActionHandler: renameActionHandler,
            tracksProvider: tracksProvider,
            badgeProvider: badgeProvider,
            eventProvider: makeEventProvider(),
            runtimeController: LibraryTrackRuntimeController(
                runtimeSnapshotStore: runtimeSnapshotStore,
                runtimeSnapshotBuilder: runtimeSnapshotBuilder
            ),
            settingsManager: settingsManager,
            trackRegistry: trackRegistry,
            musicLibraryManager: musicLibraryManager,
            trackURLProvider: { [trackRegistry] trackId in
                await BookmarkResolver.url(forTrack: trackId, trackRegistry: trackRegistry)
            },
            batchRenameHandler: makeBatchRenameHandler(),
            batchTagEditHandler: makeBatchTagEditHandler(),
            usesLibrarySortSettings: usesLibrarySortSettings
        )
    }
}
