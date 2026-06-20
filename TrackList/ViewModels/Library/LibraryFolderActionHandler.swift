//
//  LibraryFolderActionHandler.swift
//  TrackList
//
//  Обрабатывает действия экрана папки фонотеки.
//  Здесь находятся навигация и побочные эффекты, а не во View.
//
//  Created by Pavel Fomin on 20.06.2026.
//
import Foundation

@MainActor
final class LibraryFolderActionHandler {
    // MARK: - Dependencies

    private let navigationCoordinator: NavigationCoordinator
    private let clearSelectionActionBar: @MainActor () -> Void

    // MARK: - Init

    init(
        navigationCoordinator: NavigationCoordinator,
        clearSelectionActionBar: @escaping @MainActor () -> Void
    ) {
        self.navigationCoordinator = navigationCoordinator
        self.clearSelectionActionBar = clearSelectionActionBar
    }

    // MARK: - Handle

    func handle(_ action: LibraryFolderAction) {
        switch action {
        case .appeared:
            clearSelectionActionBar()
        case .subfolderTapped(let subfolder):
            navigationCoordinator.pushFolder(subfolder.url.libraryFolderId)
        }
    }
}
