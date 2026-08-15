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
struct LibraryScreenViewModelFactory {

    /// Координатор маршрутов фонотеки, подготовленный Composition Root.
    private let navigationCoordinator: NavigationCoordinator
    /// Менеджер фонотеки, подготовленный Composition Root.
    private let musicLibraryManager: MusicLibraryManager
    /// Реестр треков, подготовленный Composition Root.
    private let trackRegistry: TrackRegistry
    /// Презентер ошибок фонотеки, подготовленный Composition Root.
    private let toastPresenter: any ToastPresenting
    /// Источник событий треков, подготовленный Composition Root.
    private let trackEventProvider: any LibraryTrackEventProvider

    /// Получает готовые production-зависимости и не разрешает singleton самостоятельно.
    init(
        navigationCoordinator: NavigationCoordinator,
        musicLibraryManager: MusicLibraryManager,
        trackRegistry: TrackRegistry,
        toastPresenter: any ToastPresenting,
        trackEventProvider: any LibraryTrackEventProvider
    ) {
        self.navigationCoordinator = navigationCoordinator
        self.musicLibraryManager = musicLibraryManager
        self.trackRegistry = trackRegistry
        self.toastPresenter = toastPresenter
        self.trackEventProvider = trackEventProvider
    }

    /// Собирает ViewModel без доступа к глобальному графу зависимостей.
    func make() -> LibraryScreenViewModel {
        let stateBuilder = LibraryScreenStateBuilder()
        let actionHandler = LibraryScreenActionHandler(
            navigationCoordinator: navigationCoordinator,
            musicLibraryManager: musicLibraryManager,
            trackRegistry: trackRegistry,
            toastPresenter: toastPresenter
        )
        // Один provider обслуживает общий builder значений и корневых счётчиков.
        let collectionValuesProvider = makeCollectionValuesProvider()

        return LibraryScreenViewModel(
            navigationCoordinator: navigationCoordinator,
            musicLibraryManager: musicLibraryManager,
            stateBuilder: stateBuilder,
            actionHandler: actionHandler,
            collectionRootItemsProvider: collectionValuesProvider,
            trackEventProvider: trackEventProvider
        )
    }

    /// Создаёт provider только из зависимости, уже подготовленной Composition Root.
    private func makeCollectionValuesProvider() -> DefaultLibraryCollectionValuesProvider {
        DefaultLibraryCollectionValuesProvider(trackRegistry: trackRegistry)
    }
}
