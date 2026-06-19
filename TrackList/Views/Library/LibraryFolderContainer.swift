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
    let playerViewModel: PlayerViewModel
    @Binding var selectionActionBarConfig: SelectionActionBarConfig?

    // MARK: - Init

    init(
        folder: LibraryFolder,
        revealRequest: LibraryRevealRequest? = nil,
        onRevealHandled: @escaping (UUID) -> Void = { _ in },
        playerViewModel: PlayerViewModel,
        selectionActionBarConfig: Binding<SelectionActionBarConfig?>
    ) {
        self.folder = folder
        self.revealRequest = revealRequest
        self.onRevealHandled = onRevealHandled
        self.playerViewModel = playerViewModel
        self._selectionActionBarConfig = selectionActionBarConfig
    }

    // MARK: - UI

    var body: some View {
        LibraryFolderContent(
            folder: folder,
            revealRequest: revealRequest,
            onRevealHandled: onRevealHandled,
            playerViewModel: playerViewModel,
            selectionActionBarConfig: $selectionActionBarConfig
        )
        .id(folder.id)
    }
}

private struct LibraryFolderContent: View {

    // MARK: - Входные данные

    let folder: LibraryFolder
    let revealRequest: LibraryRevealRequest?
    let onRevealHandled: (UUID) -> Void
    let playerViewModel: PlayerViewModel
    @Binding var selectionActionBarConfig: SelectionActionBarConfig?

    // MARK: - ViewModel

    @StateObject private var viewModel: LibraryFolderViewModel

    // MARK: - Init

    init(
        folder: LibraryFolder,
        revealRequest: LibraryRevealRequest?,
        onRevealHandled: @escaping (UUID) -> Void,
        playerViewModel: PlayerViewModel,
        selectionActionBarConfig: Binding<SelectionActionBarConfig?>
    ) {
        self.folder = folder
        self.revealRequest = revealRequest
        self.onRevealHandled = onRevealHandled
        self.playerViewModel = playerViewModel
        self._selectionActionBarConfig = selectionActionBarConfig
        self._viewModel = StateObject(wrappedValue: LibraryFolderViewModel(folder: folder))
    }

    // MARK: - UI

    var body: some View {
        LibraryFolderView(
            revealRequest: revealRequest,
            onRevealHandled: onRevealHandled,
            playerViewModel: playerViewModel,
            selectionActionBarConfig: $selectionActionBarConfig
        )
        .environmentObject(viewModel)
    }
}
