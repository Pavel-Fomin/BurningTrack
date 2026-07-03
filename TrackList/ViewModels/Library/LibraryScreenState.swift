//
//  LibraryScreenState.swift
//  TrackList
//
//  Состояние контейнера фонотеки.
//  View получает готовые данные для NavigationStack и destination-экранов.
//
//  Created by Pavel Fomin on 20.06.2026.
//
import Foundation

struct LibraryScreenState {
    // MARK: - Navigation

    let libraryPath: [NavigationCoordinator.LibraryRoute]
    let destinations: [NavigationCoordinator.LibraryRoute: LibraryScreenDestinationState]

    // MARK: - Destination

    func destination(for route: NavigationCoordinator.LibraryRoute) -> LibraryScreenDestinationState {
        destinations[route] ?? .missingFolder
    }
}

enum LibraryScreenDestinationState {
    case root
    /// Экран виртуального источника iTunes, который не является папкой фонотеки.
    case purchasedITunes
    case folder(LibraryScreenFolderDestinationState)
    case missingFolder
}

struct LibraryScreenFolderDestinationState {
    let folder: LibraryFolder
    let revealRequest: LibraryRevealRequest?
}
