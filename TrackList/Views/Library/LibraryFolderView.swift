//
//  LibraryFolderView.swift
//  TrackList
//
//  Экран вложенной папки:
//  - показывает подпапки,
//  - либо список треков (через LibraryTracksView),
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

            case .tracks:
                LibraryTracksView(
                    folder: state.folder,
                    revealRequest: revealRequest,
                    onRevealHandled: onRevealHandled,
                    playerViewModel: playerViewModel,
                    selectionActionBarConfig: $selectionActionBarConfig
                
                )

            case .subfolders:
                List { folderSectionView() }
                    .listStyle(.insetGrouped)
                    .libraryToolbar(title: state.title)
                    .onAppear {
                        onAction(.appeared)
                    }

            case .empty:
                Color.clear
                    .libraryToolbar(title: state.title)
                    .onAppear {
                        onAction(.appeared)
                    }
            }
        }
    }
    
    // MARK: - Секция подпапок

    @ViewBuilder
    private func folderSectionView() -> some View {
        Section {
            ForEach(state.subfolders) { subfolder in
                HStack(spacing: 12) {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)

                    Text(subfolder.name)
                        .lineLimit(1)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    onAction(.subfolderTapped(subfolder))
                }
            }
        }
    }
}
