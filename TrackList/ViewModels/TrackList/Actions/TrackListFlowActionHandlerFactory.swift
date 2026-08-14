//
//  TrackListFlowActionHandlerFactory.swift
//  TrackList
//
//  Собирает ActionHandler detail-flow треклиста из зависимостей Composition Root.
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
    /// Менеджер сохраняет порядок строк одного треклиста и публикует invalidation-события.
    private let trackListManager: any TrackListManaging
    /// Общий handler файлового rename-flow, подготовленный Composition Root.
    private let fileRenamer: any TrackFileRenaming
    /// Презентер пользовательских сообщений, подготовленный Composition Root.
    private let toastPresenter: any ToastPresenting
    /// Обработчик переходов к значениям музыкальной коллекции, подготовленный Composition Root.
    private let collectionNavigationHandler: any TrackCollectionNavigating
    /// Общий action flow отправки трека, подготовленный Composition Root.
    private let trackShareActionHandler: TrackShareActionHandler
    /// Типизированный вход в глобальный Export-feature.
    private let exportRequestHandler: any ExportRequestHandling
    /// Реактивное playback-состояние, подготовленное Composition Root.
    private let playbackStateProvider: any PlaybackStateProviding
    /// Минимальный набор playback-команд, подготовленный Composition Root.
    private let playbackController: any TrackPlaybackControlling

    /// Получает готовые production-зависимости и не разрешает singleton самостоятельно.
    init(
        sheetManager: SheetManager,
        sheetActionCoordinator: SheetActionCoordinator,
        commandExecutor: AppCommandExecutor,
        trackListManager: any TrackListManaging,
        fileRenamer: any TrackFileRenaming,
        toastPresenter: any ToastPresenting,
        collectionNavigationHandler: any TrackCollectionNavigating,
        trackShareActionHandler: TrackShareActionHandler,
        exportRequestHandler: any ExportRequestHandling,
        playbackStateProvider: any PlaybackStateProviding,
        playbackController: any TrackPlaybackControlling
    ) {
        self.sheetManager = sheetManager
        self.sheetActionCoordinator = sheetActionCoordinator
        self.commandExecutor = commandExecutor
        self.trackListManager = trackListManager
        self.fileRenamer = fileRenamer
        self.toastPresenter = toastPresenter
        self.collectionNavigationHandler = collectionNavigationHandler
        self.trackShareActionHandler = trackShareActionHandler
        self.exportRequestHandler = exportRequestHandler
        self.playbackStateProvider = playbackStateProvider
        self.playbackController = playbackController
    }

    /// Создаёт production action handler для detail-flow одного треклиста.
    func make(
        reader: any TrackListReading,
        favoriteTrackActionHandler: FavoriteTrackActionHandler
    ) -> TrackListFlowActionHandler {
        TrackListFlowActionHandler(
            reader: reader,
            playbackStateProvider: playbackStateProvider,
            playbackController: playbackController,
            trackListManager: trackListManager,
            commandExecutor: commandExecutor,
            fileRenamer: fileRenamer,
            presenter: SheetTrackListPresenter(
                sheetManager: sheetManager,
                sheetActionCoordinator: sheetActionCoordinator
            ),
            exportRequestHandler: exportRequestHandler,
            toastPresenter: toastPresenter,
            appCommandExecutor: commandExecutor,
            collectionNavigationHandler: collectionNavigationHandler,
            trackShareActionHandler: trackShareActionHandler,
            favoriteTrackActionHandler: favoriteTrackActionHandler
        )
    }
}
