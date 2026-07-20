//
//  LibraryFolderView.swift
//  TrackList
//
//  Экран вложенной папки:
//  - показывает всё содержимое папки через LibraryTracksView,
//  - выполняет только UI и пользовательские действия.
//
//  Вся навигация:
//  - переход на подпапку → LibraryFolderActionHandler
//  - reveal/переадресация → обрабатывается в LibraryScreen, не здесь.
//
//  Created by Pavel Fomin on 27.06.2025.
//

import SwiftUI

struct LibraryFolderView: View {
    // MARK: - State

    let state: LibraryFolderScreenState

    // MARK: - Входные данные

    let revealRequest: LibraryRevealRequest?
    let onRevealHandled: (UUID) -> Void
    let playerViewModel: PlayerViewModel
    @Binding var selectionActionBarConfig: SelectionActionBarConfig?

    // MARK: - Actions

    let onAction: (LibraryFolderAction) -> Void

    // MARK: - UI

    var body: some View {
        Group {
            switch state.displayMode {

            case .content:
                LibraryTracksView(
                    folder: state.folder,
                    subfolders: state.subfolders,
                    onSubfolderTap: { subfolder in
                        onAction(.subfolderTapped(subfolder))
                    },
                    onExportTracks: { libraryTracks in
                        onAction(.exportTracks(libraryTracks))
                    },
                    revealRequest: revealRequest,
                    onRevealHandled: onRevealHandled,
                    playerViewModel: playerViewModel,
                    selectionActionBarConfig: $selectionActionBarConfig
                )

            case .empty:
                Color.clear
                    // Пустая папка остаётся обычным destination внутри родительского NavigationStack.
                    .navigationTitle(state.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .onAppear {
                        onAction(.appeared)
                    }
            }
        }
    }
}
