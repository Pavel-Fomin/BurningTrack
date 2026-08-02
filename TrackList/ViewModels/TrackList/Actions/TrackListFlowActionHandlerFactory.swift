//
//  TrackListFlowActionHandlerFactory.swift
//  TrackList
//
//  Created by Pavel Fomin on 18.06.2026.
//

import Foundation

/// Собирает production action handler для detail-flow одного треклиста.
@MainActor
struct TrackListFlowActionHandlerFactory {

    /// Менеджер sheet-состояния, подготовленный Composition Root.
    private let sheetManager: SheetManager
    /// Координатор sheet-действий, подготовленный Composition Root.
    private let sheetActionCoordinator: SheetActionCoordinator
    /// Исполнитель команд приложения, подготовленный Composition Root.
    private let commandExecutor: AppCommandExecutor
    /// Презентер пользовательских сообщений, подготовленный Composition Root.
    private let toastPresenter: any ToastPresenting
    /// Обработчик переходов к значениям музыкальной коллекции, подготовленный Composition Root.
    private let collectionNavigationHandler: TrackCollectionNavigationHandler
    /// Общий action flow отправки трека, подготовленный Composition Root.
    private let trackShareActionHandler: TrackShareActionHandler
    /// Провайдер системного контроллера, подготовленный Composition Root.
    private let viewControllerProvider: any ViewControllerProviding
    /// Реактивное playback-состояние, подготовленное Composition Root.
    private let playbackStateProvider: any PlaybackStateProviding
    /// Минимальный набор playback-команд, подготовленный Composition Root.
    private let playbackController: any TrackPlaybackControlling

    /// Получает готовые production-зависимости и не разрешает singleton самостоятельно.
    init(
        sheetManager: SheetManager,
        sheetActionCoordinator: SheetActionCoordinator,
        commandExecutor: AppCommandExecutor,
        toastPresenter: any ToastPresenting,
        collectionNavigationHandler: TrackCollectionNavigationHandler,
        trackShareActionHandler: TrackShareActionHandler,
        viewControllerProvider: any ViewControllerProviding,
        playbackStateProvider: any PlaybackStateProviding,
        playbackController: any TrackPlaybackControlling
    ) {
        self.sheetManager = sheetManager
        self.sheetActionCoordinator = sheetActionCoordinator
        self.commandExecutor = commandExecutor
        self.toastPresenter = toastPresenter
        self.collectionNavigationHandler = collectionNavigationHandler
        self.trackShareActionHandler = trackShareActionHandler
        self.viewControllerProvider = viewControllerProvider
        self.playbackStateProvider = playbackStateProvider
        self.playbackController = playbackController
    }

    /// Создаёт production action handler для detail-flow одного треклиста.
    func make(
        reader: any TrackListReading,
        mutator: any TrackListMutating,
        renamer: any TrackListRenaming,
        exportProgressViewModel: ExportProgressViewModel,
        favoriteTrackActionHandler: FavoriteTrackActionHandler
    ) -> TrackListFlowActionHandler {
        TrackListFlowActionHandler(
            reader: reader,
            playbackStateProvider: playbackStateProvider,
            playbackController: playbackController,
            mutator: mutator,
            renamer: renamer,
            presenter: SheetTrackListPresenter(
                sheetManager: sheetManager,
                sheetActionCoordinator: sheetActionCoordinator
            ),
            exportProgressViewModel: exportProgressViewModel,
            viewControllerProvider: viewControllerProvider,
            toastPresenter: toastPresenter,
            commandExecutor: commandExecutor,
            collectionNavigationHandler: collectionNavigationHandler,
            trackShareActionHandler: trackShareActionHandler,
            favoriteTrackActionHandler: favoriteTrackActionHandler
        )
    }
}
