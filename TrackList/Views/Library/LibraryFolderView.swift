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
//  - переход на подпапку → NavigationCoordinator.openFolder(_)
//  - reveal/переадресация → обрабатывается в LibraryScreen, не здесь.
//
//  Created by Pavel Fomin on 27.06.2025.
//

import SwiftUI

struct LibraryFolderView: View {

    // MARK: - Входные данные

    let revealRequest: LibraryRevealRequest?
    let onRevealHandled: (UUID) -> Void
    let trackListViewModel: TrackListViewModel
    let playerViewModel: PlayerViewModel
    @Binding var selectionActionBarConfig: SelectionActionBarConfig?

    // MARK: - Навигация и ViewModel

    @ObservedObject private var nav = NavigationCoordinator.shared
    @EnvironmentObject var viewModel: LibraryFolderViewModel

    // MARK: - UI

    var body: some View {
        Group {
            switch viewModel.displayMode {

            case .tracks:
                LibraryTracksView(
                    folder: viewModel.folder,
                    revealRequest: revealRequest,
                    onRevealHandled: onRevealHandled,
                    trackListViewModel: trackListViewModel,
                    playerViewModel: playerViewModel,
                    selectionActionBarConfig: $selectionActionBarConfig
                
                )

            case .subfolders:
                List { folderSectionView() }
                    .listStyle(.insetGrouped)
                    .libraryToolbar(title: viewModel.folder.name)
                    .onAppear {
                        selectionActionBarConfig = nil
                    }

            case .empty:
                Color.clear
                    .libraryToolbar(title: viewModel.folder.name)
                    .onAppear {
                        selectionActionBarConfig = nil
                    }
            }
        }
    }
    
    // MARK: - Секция подпапок

    @ViewBuilder
    private func folderSectionView() -> some View {
        Section {
            ForEach(viewModel.subfolders) { subfolder in
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
                    nav.pushFolder(subfolder.url.libraryFolderId)
                }
            }
        }
    }
}
