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
    private let fileBusyChecker: any TrackFileBusyChecking
    private let renameActionHandler: TrackFileRenameActionHandler
    private let favoriteTrackActionHandler: FavoriteTrackActionHandler
    private let sheetManager: SheetManager
    private let cloudAvailabilityManager: any CloudTrackAvailabilityManaging
    private let collectionNavigationHandler: TrackCollectionNavigationHandler
    private let trackShareActionHandler: TrackShareActionHandler
    private let commandExecutor: AppCommandExecutor
    private let toastManager: ToastManager
    private let sheetActionCoordinator: SheetActionCoordinator

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
        fileBusyChecker: any TrackFileBusyChecking,
        renameActionHandler: TrackFileRenameActionHandler,
        favoriteTrackActionHandler: FavoriteTrackActionHandler,
        sheetManager: SheetManager,
        cloudAvailabilityManager: any CloudTrackAvailabilityManaging,
        collectionNavigationHandler: TrackCollectionNavigationHandler,
        trackShareActionHandler: TrackShareActionHandler,
        commandExecutor: AppCommandExecutor,
        toastManager: ToastManager,
        sheetActionCoordinator: SheetActionCoordinator
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
        self.fileBusyChecker = fileBusyChecker
        self.renameActionHandler = renameActionHandler
        self.favoriteTrackActionHandler = favoriteTrackActionHandler
        self.sheetManager = sheetManager
        self.cloudAvailabilityManager = cloudAvailabilityManager
        self.collectionNavigationHandler = collectionNavigationHandler
        self.trackShareActionHandler = trackShareActionHandler
        self.commandExecutor = commandExecutor
        self.toastManager = toastManager
        self.sheetActionCoordinator = sheetActionCoordinator
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

    /// Собирает graph один раз по запросу StateObject-контейнера, не из body родительского View.
    func makeScreenStore(
        folder: LibraryFolder,
        revealRequest: LibraryRevealRequest?
    ) -> LibraryTracksScreenStore {
        let viewModel = LibraryTracksViewModel(
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
            }
        )
        let presenter = LibraryTracksPresenter(
            output: viewModel,
            selectionActionBarCoordinator: LibrarySelectionActionBarCoordinator()
        )
        let actionHandler = LibraryTracksActionHandler(
            output: viewModel,
            applyBatchFilenameRename: { [weak viewModel, fileBusyChecker] in
                await viewModel?.applyBatchFilenameRename(using: fileBusyChecker)
            }
        )
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
            sheetActionCoordinator: sheetActionCoordinator,
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
}
