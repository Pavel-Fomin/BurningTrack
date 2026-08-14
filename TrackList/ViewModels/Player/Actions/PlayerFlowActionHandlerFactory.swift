//
//  PlayerFlowActionHandlerFactory.swift
//  TrackList
//
//  Собирает ActionHandler плеера из зависимостей, подготовленных Composition Root.
//
//  Created by Pavel Fomin on 19.06.2026.
//

import Foundation

/// Собирает production action handler для Player-flow.
@MainActor
struct PlayerFlowActionHandlerFactory {

    /// Готовые production-зависимости Player feature.
    private let dependencies: PlayerFeatureDependencies
    /// Типизированный вход в глобальный Export-feature.
    private let exportRequestHandler: any ExportRequestHandling

    /// Получает подготовленные Composition Root зависимости и не разрешает singleton самостоятельно.
    init(
        dependencies: PlayerFeatureDependencies,
        exportRequestHandler: any ExportRequestHandling
    ) {
        self.dependencies = dependencies
        self.exportRequestHandler = exportRequestHandler
    }

    /// Создаёт production action handler для экрана плеера.
    func make(
        playerViewModel: PlayerViewModel,
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
        let exportActionHandler = PlayerExportActionHandler(
            playlistManager: dependencies.playlistManager,
            exportRequestHandler: exportRequestHandler
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
