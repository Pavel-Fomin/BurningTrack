//
//  LibraryMasterActionHandlerFactory.swift
//  TrackList
//
//  Собирает production action handler для корневого flow фонотеки.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

@MainActor
struct LibraryMasterActionHandlerFactory {

    /// Менеджер фонотеки, подготовленный Composition Root.
    private let manager: MusicLibraryManager
    /// Координатор маршрутов фонотеки, подготовленный Composition Root.
    private let navigationCoordinator: NavigationCoordinator
    /// Презентер пользовательских сообщений, подготовленный Composition Root.
    private let toastPresenter: any ToastPresenting
    /// Состояние плеера, подготовленное Composition Root.
    private let playbackState: any PlaybackStateProviding
    /// Команды плеера, подготовленные Composition Root.
    private let playbackController: any TrackPlaybackControlling

    /// Получает готовые production-зависимости и не разрешает singleton самостоятельно.
    init(
        manager: MusicLibraryManager,
        navigationCoordinator: NavigationCoordinator,
        toastPresenter: any ToastPresenting,
        playbackState: any PlaybackStateProviding,
        playbackController: any TrackPlaybackControlling
    ) {
        self.manager = manager
        self.navigationCoordinator = navigationCoordinator
        self.toastPresenter = toastPresenter
        self.playbackState = playbackState
        self.playbackController = playbackController
    }

    /// Создаёт production action handler из явно переданных зависимостей feature.
    func make(
        output: any LibraryMasterActionOutput,
        requestFolderPicker: @escaping @MainActor () -> Void
    ) -> LibraryMasterActionHandler {
        LibraryMasterActionHandler(
            manager: manager,
            navigationCoordinator: navigationCoordinator,
            toastPresenter: toastPresenter,
            playbackState: playbackState,
            playbackController: playbackController,
            output: output,
            requestFolderPicker: requestFolderPicker
        )
    }
}
