//
//  PlayerScreen.swift
//  TrackList
//
//  Вкладка “Плеер”
//
//  Created by Pavel Fomin on 22.06.2025.
//

import SwiftUI

struct PlayerScreen: View {

    @ObservedObject var playerViewModel: PlayerViewModel

    @StateObject private var screenViewModel: PlayerScreenViewModel

    init(
        playerViewModel: PlayerViewModel
    ) {
        self.playerViewModel = playerViewModel
        let trackFileRenameActionHandler = TrackFileRenameActionHandler(
            playerManager: playerViewModel.playerManager,
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
        let exportActionHandler = PlayerExportActionHandler(
            playlistManager: PlaylistManager.shared,
            exportManager: ExportManager.shared,
            toastManager: ToastManager.shared,
            presenterProvider: {
                UIApplication.topViewController()
            }
        )
        let playerRenameActionHandler = PlayerRenameActionHandler(
            playlistManager: PlaylistManager.shared,
            playerViewModel: playerViewModel,
            trackFileRenameActionHandler: trackFileRenameActionHandler
        )
        let rowStateBuilder = PlayerTrackRowStateBuilder(
            artworkProvider: ArtworkProvider.shared
        )
        let actionHandler = PlayerFlowActionHandler(
            playbackActionHandler: playbackActionHandler,
            queueActionHandler: queueActionHandler,
            presentationActionHandler: presentationActionHandler,
            exportActionHandler: exportActionHandler,
            renameActionHandler: playerRenameActionHandler
        )
        _screenViewModel = StateObject(
            wrappedValue: PlayerScreenViewModel(
                playerViewModel: playerViewModel,
                actionHandler: actionHandler,
                sheetManager: SheetManager.shared,
                playlistManager: PlaylistManager.shared,
                appSettingsManager: AppSettingsManager.shared,
                rowStateBuilder: rowStateBuilder
            )
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    PlayerPlaylistView(
                        screenViewModel: screenViewModel
                    )
                }
            }
            .playerToolbar(
                trackCount: screenViewModel.state.trackCount,
                onSave: {
                    screenViewModel.handle(.saveTrackList)
                },
                onExport: {
                    screenViewModel.handle(.exportTrackList)
                },
                onClear: {
                    screenViewModel.handle(.clearTrackList)
                }
            )
        }
        .miniPlayerHost(
            playerViewModel: playerViewModel
        )
    }
}
