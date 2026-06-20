//
//  LibraryScreenViewModelFactory.swift
//  TrackList
//
//  Фабрика ViewModel контейнера фонотеки.
//  Собирает production-зависимости без DI-контейнера.
//
//  Created by Pavel Fomin on 20.06.2026.
//
import Foundation

@MainActor
enum LibraryScreenViewModelFactory {
    // MARK: - Make

    static func make() -> LibraryScreenViewModel {
        make(
            navigationCoordinator: .shared,
            musicLibraryManager: .shared,
            trackRegistry: .shared,
            toastPresenter: ToastManager.shared
        )
    }

    static func make(
        navigationCoordinator: NavigationCoordinator,
        musicLibraryManager: MusicLibraryManager,
        trackRegistry: TrackRegistry,
        toastPresenter: any ToastPresenting
    ) -> LibraryScreenViewModel {
        let stateBuilder = LibraryScreenStateBuilder()
        let actionHandler = LibraryScreenActionHandler(
            navigationCoordinator: navigationCoordinator,
            musicLibraryManager: musicLibraryManager,
            trackRegistry: trackRegistry,
            toastPresenter: toastPresenter
        )

        return LibraryScreenViewModel(
            navigationCoordinator: navigationCoordinator,
            musicLibraryManager: musicLibraryManager,
            stateBuilder: stateBuilder,
            actionHandler: actionHandler
        )
    }
}
