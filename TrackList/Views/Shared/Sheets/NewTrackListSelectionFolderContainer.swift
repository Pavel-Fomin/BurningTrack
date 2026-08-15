//
//  NewTrackListSelectionFolderContainer.swift
//  TrackList
//
//  Удерживает graph папки в selection-flow треклиста.
//
//  Created by Pavel Fomin on 03.08.2026.
//

import SwiftUI

/// Создаёт selection-folder graph один раз через существующую Library Tracks factory.
struct NewTrackListSelectionFolderContainer: View {
    /// Открытая папка фонотеки.
    let folder: LibraryFolder
    /// Единая ViewModel выбора треков всего sheet-flow.
    @ObservedObject var selectionViewModel: NewTrackListSelectionViewModel
    /// Factory вложенных папок сохраняет тот же composition root.
    let folderViewFactory: NewTrackListSelectionFolderViewFactory

    /// Store удерживает Library Tracks, presentation-state и action ingress одного destination.
    @StateObject private var screenStore: NewTrackListSelectionFolderScreenStore

    init(
        folder: LibraryFolder,
        selectionViewModel: NewTrackListSelectionViewModel,
        folderViewFactory: NewTrackListSelectionFolderViewFactory
    ) {
        self.folder = folder
        self.selectionViewModel = selectionViewModel
        self.folderViewFactory = folderViewFactory
        _screenStore = StateObject(
            wrappedValue: folderViewFactory.makeScreenStore(
                folder: folder,
                selectionViewModel: selectionViewModel
            )
        )
    }

    var body: some View {
        NewTrackListSelectionFolderView(
            folder: folder,
            folderViewFactory: folderViewFactory,
            selectionViewModel: selectionViewModel,
            screenStore: screenStore
        )
    }
}
