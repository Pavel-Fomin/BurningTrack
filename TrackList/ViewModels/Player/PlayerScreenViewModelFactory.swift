//
//  PlayerScreenViewModelFactory.swift
//  TrackList
//
//  Собирает ScreenState-flow плеера из зависимостей, подготовленных Composition Root.
//
//  Created by Pavel Fomin on 19.06.2026.
//

import Foundation

/// Собирает production ViewModel для экрана плеера.
@MainActor
struct PlayerScreenViewModelFactory {

    /// Готовые production-зависимости Player feature.
    private let dependencies: PlayerFeatureDependencies
    /// Фабрика production-обработчика действий Player-flow с теми же зависимостями.
    private let actionHandlerFactory: PlayerFlowActionHandlerFactory

    /// Получает подготовленные Composition Root зависимости и не разрешает singleton самостоятельно.
    init(
        dependencies: PlayerFeatureDependencies,
        exportRequestHandler: any ExportRequestHandling
    ) {
        self.dependencies = dependencies
        self.actionHandlerFactory = PlayerFlowActionHandlerFactory(
            dependencies: dependencies,
            exportRequestHandler: exportRequestHandler
        )
    }

    /// Создаёт production ViewModel для Player-flow.
    func make(
        playerViewModel: PlayerViewModel,
        favoriteTrackActionHandler: FavoriteTrackActionHandler
    ) -> PlayerScreenViewModel {
        let rowStateBuilder = PlayerTrackRowStateBuilder()

        return PlayerScreenViewModel(
            playerViewModel: playerViewModel,
            actionHandler: actionHandlerFactory.make(
                playerViewModel: playerViewModel,
                favoriteTrackActionHandler: favoriteTrackActionHandler
            ),
            sheetManager: dependencies.sheetManager,
            playlistManager: dependencies.playlistManager,
            appSettingsManager: dependencies.appSettingsManager,
            trackRegistry: dependencies.trackRegistry,
            rowStateBuilder: rowStateBuilder
        )
    }
}
