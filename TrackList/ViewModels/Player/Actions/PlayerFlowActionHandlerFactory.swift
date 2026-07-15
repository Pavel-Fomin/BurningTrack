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
        playerViewModel: PlayerViewModel,
        exportProgressViewModel: ExportProgressViewModel
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
            sheetActionCoordinator: SheetActionCoordinator.shared,
            toastPresenter: ToastManager.shared
        )
        let viewControllerProvider = ApplicationViewControllerProvider()
        let exportActionHandler = PlayerExportActionHandler(
            playlistManager: PlaylistManager.shared,
            exportProgressViewModel: exportProgressViewModel,
            toastManager: ToastManager.shared,
            presenterProvider: {
                viewControllerProvider.topViewController()
            }
        )
        let renameActionHandler = PlayerRenameActionHandler(
            playlistManager: PlaylistManager.shared,
            playerViewModel: playerViewModel,
            trackFileRenameActionHandler: trackFileRenameActionHandler,
            toastPresenter: ToastManager.shared
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
