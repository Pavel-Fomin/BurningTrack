//
//  NewTrackListSelectionFolderContainer.swift
//  TrackList
//
//  Удерживает graph папки в selection-flow треклиста.
//
//  Created by Pavel Fomin on 03.08.2026.
//

import SwiftUI

/// Создаёт ViewModel Library Tracks один раз через существующую factory, а не во View папки.
struct NewTrackListSelectionFolderContainer: View {
    /// Открытая папка фонотеки.
    let folder: LibraryFolder
    /// Единая ViewModel выбора треков всего sheet-flow.
    @ObservedObject var selectionViewModel: NewTrackListSelectionViewModel
    /// Published-снимок «Избранного» для presentation-состояния строк.
    let favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    /// Factory вложенных папок сохраняет тот же composition root.
    let folderViewFactory: NewTrackListSelectionFolderViewFactory

    /// Готовая ViewModel папки, созданная только в initializer destination-контейнера.
    @StateObject private var tracksViewModel: LibraryTracksViewModel

    init(
        folder: LibraryFolder,
        selectionViewModel: NewTrackListSelectionViewModel,
        libraryTracksScreenFactory: LibraryTracksScreenFactory,
        favoriteTrackIdsProvider: any FavoriteTrackIdsProviding,
        folderViewFactory: NewTrackListSelectionFolderViewFactory
    ) {
        self.folder = folder
        self.selectionViewModel = selectionViewModel
        self.favoriteTrackIdsProvider = favoriteTrackIdsProvider
        self.folderViewFactory = folderViewFactory
        _tracksViewModel = StateObject(
            wrappedValue: libraryTracksScreenFactory.makeSelectionTracksViewModel(
                folder: folder
            )
        )
    }

    var body: some View {
        NewTrackListSelectionFolderView(
            folder: folder,
            folderViewFactory: folderViewFactory,
            selectionViewModel: selectionViewModel,
            favoriteTrackIdsProvider: favoriteTrackIdsProvider,
            tracksViewModel: tracksViewModel
        )
    }
}
