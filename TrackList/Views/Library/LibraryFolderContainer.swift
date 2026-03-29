//
//  LibraryFolderContainer.swift
//  TrackList
//
//  Контейнер экрана папки фонотеки.
//  Создаёт и удерживает LibraryFolderViewModel через StateObject,
//  чтобы ViewModel не пересоздавалась при каждом пересчёте SwiftUI.
//
//  Created by Pavel Fomin on 29.03.2026.
//

import SwiftUI

struct LibraryFolderContainer: View {

    // MARK: - Входные данные

    let folder: LibraryFolder
    let trackListViewModel: TrackListViewModel
    let playerViewModel: PlayerViewModel

    // MARK: - ViewModel

    @StateObject private var viewModel: LibraryFolderViewModel

    // MARK: - Init

    init(
        folder: LibraryFolder,
        trackListViewModel: TrackListViewModel,
        playerViewModel: PlayerViewModel
    ) {
        self.folder = folder
        self.trackListViewModel = trackListViewModel
        self.playerViewModel = playerViewModel
        self._viewModel = StateObject(wrappedValue: LibraryFolderViewModel(folder: folder))
    }

    // MARK: - UI

    var body: some View {
        LibraryFolderView(
            trackListViewModel: trackListViewModel,
            playerViewModel: playerViewModel
        )
        .environmentObject(viewModel)
    }
}
