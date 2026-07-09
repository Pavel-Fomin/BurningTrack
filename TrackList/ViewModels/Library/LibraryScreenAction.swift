//
//  LibraryScreenAction.swift
//  TrackList
//
//  Действия контейнера фонотеки.
//  View отправляет действия, а обработчик выполняет навигацию и побочные эффекты.
//
//  Created by Pavel Fomin on 20.06.2026.
//
import Foundation

enum LibraryScreenAction {
    case appeared
    case collectionCategorySelected(LibraryCollectionCategory)
    case collectionValueSelected(LibraryCollectionValue)
    case libraryPathChanged([NavigationCoordinator.LibraryRoute])
    case revealHandled(UUID)
    case folderMissingAppeared
}
