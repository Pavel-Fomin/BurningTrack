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

    // MARK: - Навигация и ViewModel

    @ObservedObject private var nav = NavigationCoordinator.shared
    @EnvironmentObject var viewModel: LibraryFolderViewModel
    
    @State private var selection = Set<UUID>()

    // MARK: - UI

    var body: some View {
        Group {
            
            let _ = print("📌 LibraryFolderView displayMode:", viewModel.displayMode)
            let _ = print("📌 folder:", viewModel.folder.name, "subfolders:", viewModel.subfolders.count)
            
            switch viewModel.displayMode {

            case .tracks:
                LibraryTracksView(
                    folder: viewModel.folder,
                    revealRequest: revealRequest,
                    onRevealHandled: onRevealHandled,
                    trackListViewModel: trackListViewModel,
                    playerViewModel: playerViewModel
                
                )

            case .subfolders:
                List { folderSectionView() }
                    .listStyle(.insetGrouped)
                    .libraryToolbar(title: viewModel.folder.name)

            case .empty:
                Color.clear
                    .libraryToolbar(title: viewModel.folder.name)
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
