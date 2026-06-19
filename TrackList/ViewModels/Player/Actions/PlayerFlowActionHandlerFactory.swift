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

    /// Создаёт production action handler для экрана плеера.
    func make(
        playerViewModel: PlayerViewModel
    ) -> PlayerFlowActionHandler {
        let trackFileRenameActionHandler = TrackFileRenameActionHandler(
            playerManager: playerViewModel.fileOperationPlayerManager,
            sheetManager: SheetManager.shared,
            commandExecutor: AppCommandExecutor.shared,
            toastManager: ToastManager.shared,
            proposalBuilder: FileRenameProposalBuilder()
        )
        let playbackActionHandler = PlayerPlaybackActionHandler(
            playerViewModel: playerViewModel,
            playlistManager: PlaylistManager.shared
        )
        let queueActionHandler = PlayerQueueActionHandler(
            playlistManager: PlaylistManager.shared,
            commandExecutor: AppCommandExecutor.shared,
            toastManager: ToastManager.shared
        )
        let presentationActionHandler = PlayerPresentationActionHandler(
            playlistManager: PlaylistManager.shared,
            sheetManager: SheetManager.shared,
            sheetActionCoordinator: SheetActionCoordinator.shared
        )
        let viewControllerProvider = ApplicationViewControllerProvider()
        let exportActionHandler = PlayerExportActionHandler(
            playlistManager: PlaylistManager.shared,
            exportManager: ExportManager.shared,
            toastManager: ToastManager.shared,
            presenterProvider: {
                viewControllerProvider.topViewController()
            }
        )
        let renameActionHandler = PlayerRenameActionHandler(
            playlistManager: PlaylistManager.shared,
            playerViewModel: playerViewModel,
            trackFileRenameActionHandler: trackFileRenameActionHandler
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
