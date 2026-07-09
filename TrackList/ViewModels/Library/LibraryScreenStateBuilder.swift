//
//  LibraryScreenStateBuilder.swift
//  TrackList
//
//  Собирает состояние контейнера фонотеки из координатора навигации и менеджера фонотеки.
//
//  Created by Pavel Fomin on 20.06.2026.
//
import Foundation

struct LibraryScreenStateBuilder {
    // MARK: - Build

    @MainActor
    func build(
        navigationCoordinator: NavigationCoordinator,
        musicLibraryManager: MusicLibraryManager
    ) -> LibraryScreenState {
        var destinations: [NavigationCoordinator.LibraryRoute: LibraryScreenDestinationState] = [
            .root: .root,
            // Виртуальный источник всегда доступен в корне и не зависит от списка папок.
            .purchasedITunes: .purchasedITunes
        ]

        for category in LibraryCollectionCategory.allCases {
            // Разделы коллекции открывают свои экраны значений через общую маршрутизацию.
            destinations[.collectionCategory(category)] = .collectionCategory(category)
        }

        for folder in musicLibraryManager.attachedFolders {
            appendDestination(
                for: folder,
                pendingRevealRequest: navigationCoordinator.pendingRevealRequest,
                destinations: &destinations
            )
        }

        return LibraryScreenState(
            libraryPath: navigationCoordinator.libraryPath,
            destinations: destinations
        )
    }

    // MARK: - Private

    private func appendDestination(
        for folder: LibraryFolder,
        pendingRevealRequest: LibraryRevealRequest?,
        destinations: inout [NavigationCoordinator.LibraryRoute: LibraryScreenDestinationState]
    ) {
        let revealRequest = revealRequest(
            for: folder.id,
            pendingRevealRequest: pendingRevealRequest
        )

        destinations[.folder(folder.id)] = .folder(
            LibraryScreenFolderDestinationState(
                folder: folder,
                revealRequest: revealRequest
            )
        )

        for subfolder in folder.subfolders {
            appendDestination(
                for: subfolder,
                pendingRevealRequest: pendingRevealRequest,
                destinations: &destinations
            )
        }
    }

    private func revealRequest(
        for folderId: UUID,
        pendingRevealRequest: LibraryRevealRequest?
    ) -> LibraryRevealRequest? {
        guard pendingRevealRequest?.folderId == folderId else { return nil }
        return pendingRevealRequest
    }
}
