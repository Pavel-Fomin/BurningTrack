//
//  PlayerFlowActionHandlerFactory.swift
//  TrackList
//
//  Created by Pavel Fomin on 19.06.2026.
//

import Foundation

/// Собирает production action handler для Player-flow.
@MainActor
struct PlayerFlowActionHandlerFactory {

    /// Готовые production-зависимости Player feature.
    private let dependencies: PlayerFeatureDependencies

    /// Получает подготовленные Composition Root зависимости и не разрешает singleton самостоятельно.
    init(dependencies: PlayerFeatureDependencies) {
        self.dependencies = dependencies
    }

    /// Создаёт production action handler для экрана плеера.
    func make(
        playerViewModel: PlayerViewModel,
        exportProgressViewModel: ExportProgressViewModel,
        favoriteTrackActionHandler: FavoriteTrackActionHandler
    ) -> PlayerFlowActionHandler {
        let playbackActionHandler = PlayerPlaybackActionHandler(
            playerViewModel: playerViewModel,
            playlistManager: dependencies.playlistManager
        )
        let queueActionHandler = PlayerQueueActionHandler(
            playlistManager: dependencies.playlistManager,
            commandExecutor: dependencies.commandExecutor,
            toastManager: dependencies.toastManager
        )
        let presentationActionHandler = PlayerPresentationActionHandler(
            playlistManager: dependencies.playlistManager,
            sheetManager: dependencies.sheetManager,
            sheetActionCoordinator: dependencies.sheetActionCoordinator,
            toastPresenter: dependencies.toastManager,
            collectionNavigationHandler: dependencies.collectionNavigationHandler,
            trackShareActionHandler: dependencies.trackShareActionHandler,
            favoriteActionHandler: favoriteTrackActionHandler
        )
        let viewControllerProvider = ApplicationViewControllerProvider()
        let exportActionHandler = PlayerExportActionHandler(
            playlistManager: dependencies.playlistManager,
            exportProgressViewModel: exportProgressViewModel,
            toastManager: dependencies.toastManager,
            presenterProvider: {
                viewControllerProvider.topViewController()
            }
        )
        let renameActionHandler = PlayerRenameActionHandler(
            playlistManager: dependencies.playlistManager,
            playerViewModel: playerViewModel,
            trackFileRenameActionHandler: dependencies.trackFileRenameActionHandler,
            toastPresenter: dependencies.toastManager
        )

        return PlayerFlowActionHandler(
            playbackActionHandler: playbackActionHandler,
            queueActionHandler: queueActionHandler,
            presentationActionHandler: presentationActionHandler,
            exportActionHandler: exportActionHandler,
            renameActionHandler: renameActionHandler
        )
    }
}
