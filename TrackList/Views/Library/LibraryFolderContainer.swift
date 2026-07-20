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
    let exportProgressViewModel: ExportProgressViewModel
    @Binding var selectionActionBarConfig: SelectionActionBarConfig?

    // MARK: - Init

    init(
        folder: LibraryFolder,
        revealRequest: LibraryRevealRequest? = nil,
        onRevealHandled: @escaping (UUID) -> Void = { _ in },
        playerViewModel: PlayerViewModel,
        exportProgressViewModel: ExportProgressViewModel,
        selectionActionBarConfig: Binding<SelectionActionBarConfig?>
    ) {
        self.folder = folder
        self.revealRequest = revealRequest
        self.onRevealHandled = onRevealHandled
        self.playerViewModel = playerViewModel
        self.exportProgressViewModel = exportProgressViewModel
        self._selectionActionBarConfig = selectionActionBarConfig
    }

    // MARK: - UI

    var body: some View {
        LibraryFolderContent(
            folder: folder,
            revealRequest: revealRequest,
            onRevealHandled: onRevealHandled,
            playerViewModel: playerViewModel,
            exportProgressViewModel: exportProgressViewModel,
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
    let exportProgressViewModel: ExportProgressViewModel
    @Binding var selectionActionBarConfig: SelectionActionBarConfig?

    // MARK: - ViewModel

    @StateObject private var viewModel: LibraryFolderViewModel

    // MARK: - Init

    init(
        folder: LibraryFolder,
        revealRequest: LibraryRevealRequest?,
        onRevealHandled: @escaping (UUID) -> Void,
        playerViewModel: PlayerViewModel,
        exportProgressViewModel: ExportProgressViewModel,
        selectionActionBarConfig: Binding<SelectionActionBarConfig?>
    ) {
        self.folder = folder
        self.revealRequest = revealRequest
        self.onRevealHandled = onRevealHandled
        self.playerViewModel = playerViewModel
        self.exportProgressViewModel = exportProgressViewModel
        self._selectionActionBarConfig = selectionActionBarConfig
        // Сохраняем Binding локально, чтобы action handler очищал текущую панель выбора.
        let selectionActionBarConfig = selectionActionBarConfig
        self._viewModel = StateObject(
            wrappedValue: LibraryFolderViewModelFactory.make(
                folder: folder,
                exportProgressViewModel: exportProgressViewModel,
                clearSelectionActionBar: {
                    selectionActionBarConfig.wrappedValue = nil
                }
            )
        )
    }

    // MARK: - UI

    var body: some View {
        LibraryFolderView(
            state: viewModel.screenState,
            revealRequest: revealRequest,
            onRevealHandled: onRevealHandled,
            playerViewModel: playerViewModel,
            selectionActionBarConfig: $selectionActionBarConfig,
            onAction: viewModel.handle
        )
    }
}
