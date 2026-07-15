//
//  PlayerScreenViewModelFactory.swift
//  TrackList
//
//  Created by Pavel Fomin on 19.06.2026.
//

import Foundation

/// Собирает production ViewModel для экрана плеера.
@MainActor
struct PlayerScreenViewModelFactory {

    /// Factory production-обработчика действий Player-flow.
    private let actionHandlerFactory = PlayerFlowActionHandlerFactory()

    /// Создаёт production ViewModel для Player-flow.
    func make(
        playerViewModel: PlayerViewModel,
        exportProgressViewModel: ExportProgressViewModel
    ) -> PlayerScreenViewModel {
        let rowStateBuilder = PlayerTrackRowStateBuilder(
            artworkProvider: ArtworkProvider.shared
        )

        return PlayerScreenViewModel(
            playerViewModel: playerViewModel,
            actionHandler: actionHandlerFactory.make(
                playerViewModel: playerViewModel,
                exportProgressViewModel: exportProgressViewModel
            ),
            sheetManager: SheetManager.shared,
            playlistManager: PlaylistManager.shared,
            appSettingsManager: AppSettingsManager.shared,
            rowStateBuilder: rowStateBuilder
        )
    }
}
