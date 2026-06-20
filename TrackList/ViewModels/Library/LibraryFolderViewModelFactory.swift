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
enum LibraryFolderViewModelFactory {
    // MARK: - Make

    static func make(
        folder: LibraryFolder,
        clearSelectionActionBar: @escaping @MainActor () -> Void
    ) -> LibraryFolderViewModel {
        // Используем overload вместо default-значения, чтобы обращаться к shared внутри MainActor.
        make(
            folder: folder,
            navigationCoordinator: .shared,
            clearSelectionActionBar: clearSelectionActionBar
        )
    }

    static func make(
        folder: LibraryFolder,
        navigationCoordinator: NavigationCoordinator,
        clearSelectionActionBar: @escaping @MainActor () -> Void
    ) -> LibraryFolderViewModel {
        let stateBuilder = LibraryFolderStateBuilder()
        let actionHandler = LibraryFolderActionHandler(
            navigationCoordinator: navigationCoordinator,
            clearSelectionActionBar: clearSelectionActionBar
        )
        return LibraryFolderViewModel(
            folder: folder,
            stateBuilder: stateBuilder,
            actionHandler: actionHandler
        )
    }
}
