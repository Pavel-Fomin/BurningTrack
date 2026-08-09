//
//  NewTrackListSelectionFolderViewFactory.swift
//  TrackList
//
//  Собирает дочерние экраны папок для выбора треков.
//
//  Created by Pavel Fomin on 03.08.2026.
//

import SwiftUI

/// Переиспользует каноническую factory Library Tracks для дочернего selection-flow.
@MainActor
struct NewTrackListSelectionFolderViewFactory {
    /// Точка сборки ViewModel фонотеки с явными production-зависимостями.
    private let libraryTracksScreenFactory: LibraryTracksScreenFactory
    /// Published-снимок «Избранного» для готовых строк выбора.
    private let favoriteTrackIdsProvider: any FavoriteTrackIdsProviding

    init(
        libraryTracksScreenFactory: LibraryTracksScreenFactory,
        favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    ) {
        self.libraryTracksScreenFactory = libraryTracksScreenFactory
        self.favoriteTrackIdsProvider = favoriteTrackIdsProvider
    }

    /// Возвращает container, удерживающий готовую ViewModel папки на время navigation destination.
    func makeFolderContainer(
        folder: LibraryFolder,
        selectionViewModel: NewTrackListSelectionViewModel
    ) -> NewTrackListSelectionFolderContainer {
        NewTrackListSelectionFolderContainer(
            folder: folder,
            selectionViewModel: selectionViewModel,
            libraryTracksScreenFactory: libraryTracksScreenFactory,
            favoriteTrackIdsProvider: favoriteTrackIdsProvider,
            folderViewFactory: self
        )
    }
}
