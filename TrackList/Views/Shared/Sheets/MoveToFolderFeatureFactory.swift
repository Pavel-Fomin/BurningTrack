//
//  MoveToFolderFeatureFactory.swift
//  TrackList
//
//  Собирает feature-flow выбора папки из явных зависимостей Composition Root.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Собирает Move To Folder без обращения leaf View к application-wide singleton-ам.
@MainActor
struct MoveToFolderFeatureFactory {
    /// Читает текущую папку локального трека.
    private let trackRegistry: TrackRegistry
    /// Предоставляет read-only дерево папок для локальной навигации.
    private let library: MusicLibraryManager
    /// Проверяет занятость локального файла плеером.
    private let fileBusyChecker: any TrackFileBusyChecking
    /// Выполняет существующие команды move и copy.
    private let commandExecutor: AppCommandExecutor
    /// Показывает существующий feedback файловых операций.
    private let toastPresenter: any ToastPresenting
    /// Закрывает только совпадающий route выбора папки.
    private let router: any MoveToFolderRouting

    init(
        trackRegistry: TrackRegistry,
        library: MusicLibraryManager,
        fileBusyChecker: any TrackFileBusyChecking,
        commandExecutor: AppCommandExecutor,
        toastPresenter: any ToastPresenting,
        router: any MoveToFolderRouting
    ) {
        self.trackRegistry = trackRegistry
        self.library = library
        self.fileBusyChecker = fileBusyChecker
        self.commandExecutor = commandExecutor
        self.toastPresenter = toastPresenter
        self.router = router
    }

    /// Создаёт стабильный контейнер для неизменяемого payload конкретного route.
    func makeView(data: MoveToFolderSheetData) -> MoveToFolderContainer {
        MoveToFolderContainer(
            data: data,
            trackRegistry: trackRegistry,
            library: library,
            fileBusyChecker: fileBusyChecker,
            commandExecutor: commandExecutor,
            toastPresenter: toastPresenter,
            actionHandler: MoveToFolderActionHandler(
                router: router,
                routeID: data.id
            )
        )
    }
}
