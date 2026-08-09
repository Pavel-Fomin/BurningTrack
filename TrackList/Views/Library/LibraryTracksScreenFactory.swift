//
//  LibraryTracksScreenFactory.swift
//  TrackList
//
//  Точка сборки экранной возможности Library Tracks.
//
//  Created by Pavel Fomin on 02.08.2026.
//

import SwiftUI

/// Собирает folder-вариант Library Tracks и удерживает production composition вне SwiftUI View.
@MainActor
struct LibraryTracksScreenFactory {
    private let tracksProvider: LibraryTracksProvider
    private let badgeProvider: TrackListBadgeProvider
    private let makeEventProvider: () -> any LibraryTrackEventProvider
    private let settingsManager: AppSettingsManager
    private let trackRegistry: TrackRegistry
    private let musicLibraryManager: MusicLibraryManager
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

    init(
        tracksProvider: LibraryTracksProvider,
        badgeProvider: TrackListBadgeProvider,
        makeEventProvider: @escaping () -> any LibraryTrackEventProvider,
        settingsManager: AppSettingsManager,
        trackRegistry: TrackRegistry,
        musicLibraryManager: MusicLibraryManager,
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
        toastManager: ToastManager
    ) {
        self.tracksProvider = tracksProvider
        self.badgeProvider = badgeProvider
        self.makeEventProvider = makeEventProvider
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

    /// Собирает ViewModel папки для selection-flow без создания production-зависимостей во View.
    func makeSelectionTracksViewModel(
        folder: LibraryFolder
    ) -> LibraryTracksViewModel {
        makeTracksViewModel(
            folder: folder,
            usesLibrarySortSettings: false
        )
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
            folder: folder,
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
        let presentationHandler = LibraryTrackPresentationHandler(metadataProvider: viewModel)
        let commandHandler = LibraryTrackCommandHandler(
            sheetManager: sheetManager,
            playbackHandler: LibraryTrackPlaybackHandler(
                playbackStateProvider: playbackStateProvider,
                playbackController: playbackController,
                source: .libraryFolder(id: folder.id)
            ),
            presentationHandler: presentationHandler,
            cloudAvailabilityActionHandler: LibraryCloudAvailabilityActionHandler(
                controller: cloudController
            ),
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

    /// Создаёт общую ViewModel папки, изолируя её production-зависимости внутри Library Tracks factory.
    private func makeTracksViewModel(
        folder: LibraryFolder,
        usesLibrarySortSettings: Bool
    ) -> LibraryTracksViewModel {
        LibraryTracksViewModel(
            folderURL: folder.url,
            renameActionHandler: renameActionHandler,
            tracksProvider: tracksProvider,
            badgeProvider: badgeProvider,
            eventProvider: makeEventProvider(),
            runtimeController: LibraryTrackRuntimeController(),
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
