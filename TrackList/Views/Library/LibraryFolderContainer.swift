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
    let revealRequest: LibraryRevealRequest?
    let onRevealHandled: (UUID) -> Void
    let trackListViewModel: TrackListViewModel
    let playerViewModel: PlayerViewModel

    // MARK: - Init

    init(
        folder: LibraryFolder,
        revealRequest: LibraryRevealRequest? = nil,
        onRevealHandled: @escaping (UUID) -> Void = { _ in },
        trackListViewModel: TrackListViewModel,
        playerViewModel: PlayerViewModel
    ) {
        self.folder = folder
        self.revealRequest = revealRequest
        self.onRevealHandled = onRevealHandled
        self.trackListViewModel = trackListViewModel
        self.playerViewModel = playerViewModel
    }

    // MARK: - UI

    var body: some View {
        LibraryFolderContent(
            folder: folder,
            revealRequest: revealRequest,
            onRevealHandled: onRevealHandled,
            trackListViewModel: trackListViewModel,
            playerViewModel: playerViewModel
        )
        .id(folder.id)
    }
}

private struct LibraryFolderContent: View {

    // MARK: - Входные данные

    let folder: LibraryFolder
    let revealRequest: LibraryRevealRequest?
    let onRevealHandled: (UUID) -> Void
    let trackListViewModel: TrackListViewModel
    let playerViewModel: PlayerViewModel

    // MARK: - ViewModel

    @StateObject private var viewModel: LibraryFolderViewModel

    // MARK: - Init

    init(
        folder: LibraryFolder,
        revealRequest: LibraryRevealRequest?,
        onRevealHandled: @escaping (UUID) -> Void,
        trackListViewModel: TrackListViewModel,
        playerViewModel: PlayerViewModel
    ) {
        self.folder = folder
        self.revealRequest = revealRequest
        self.onRevealHandled = onRevealHandled
        self.trackListViewModel = trackListViewModel
        self.playerViewModel = playerViewModel
        self._viewModel = StateObject(wrappedValue: LibraryFolderViewModel(folder: folder))
    }

    // MARK: - UI

    var body: some View {
        LibraryFolderView(
            revealRequest: revealRequest,
            onRevealHandled: onRevealHandled,
            trackListViewModel: trackListViewModel,
            playerViewModel: playerViewModel
        )
        .environmentObject(viewModel)
    }
}
