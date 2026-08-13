//
//  LibraryFolderViewModelFactory.swift
//  TrackList
//
//  Фабрика ViewModel экрана папки фонотеки.
//  Контейнер не должен знать детали сборки ViewModel и обработчиков.
//
//  Created by Pavel Fomin on 20.06.2026.
//
import Foundation

@MainActor
struct LibraryFolderViewModelFactory {

    /// Координатор маршрутов фонотеки, подготовленный Composition Root.
    private let navigationCoordinator: NavigationCoordinator
    /// Типизированный вход в глобальный Export-feature.
    private let exportRequestHandler: any ExportRequestHandling
    /// SQLite-провайдер статистики, подготовленный Composition Root.
    private let summaryProvider: any TrackCollectionSummaryProviding
    /// Источник событий треков, подготовленный Composition Root.
    private let eventProvider: any LibraryTrackEventProvider

    /// Получает готовые production-зависимости и не разрешает singleton самостоятельно.
    init(
        navigationCoordinator: NavigationCoordinator,
        exportRequestHandler: any ExportRequestHandling,
        summaryProvider: any TrackCollectionSummaryProviding,
        eventProvider: any LibraryTrackEventProvider
    ) {
        self.navigationCoordinator = navigationCoordinator
        self.exportRequestHandler = exportRequestHandler
        self.summaryProvider = summaryProvider
        self.eventProvider = eventProvider
    }

    /// Собирает ViewModel без доступа к глобальному графу зависимостей.
    func make(
        folder: LibraryFolder,
        clearSelectionActionBar: @escaping @MainActor () -> Void
    ) -> LibraryFolderViewModel {
        let stateBuilder = LibraryFolderStateBuilder()
        let actionHandler = LibraryFolderActionHandler(
            navigationCoordinator: navigationCoordinator,
            exportRequestHandler: exportRequestHandler,
            exportFolder: .named(folder.name),
            clearSelectionActionBar: clearSelectionActionBar
        )
        return LibraryFolderViewModel(
            folder: folder,
            stateBuilder: stateBuilder,
            actionHandler: actionHandler,
            summaryProvider: summaryProvider,
            eventProvider: eventProvider
        )
    }
}
