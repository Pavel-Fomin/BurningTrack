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
    
    let folder: LibraryFolder
    let trackListViewModel: TrackListViewModel
    @ObservedObject var playerViewModel: PlayerViewModel
    
    // MARK: - Навигация и ViewModel
    
    @ObservedObject private var nav = NavigationCoordinator.shared
    @EnvironmentObject var viewModel: LibraryFolderViewModel
    
    // MARK: - Инициализация
    
    init(
        folder: LibraryFolder,
        trackListViewModel: TrackListViewModel,
        playerViewModel: PlayerViewModel
    ) {
        self.folder = folder
        self.trackListViewModel = trackListViewModel
        self._playerViewModel = ObservedObject(wrappedValue: playerViewModel)
    }
    
    
    // MARK: - UI
    
    var body: some View {
        Group {
            switch viewModel.displayMode {
            case .tracks:
                LibraryTracksView(
                    folder: viewModel.folder,
                    trackListViewModel: trackListViewModel,
                    playerViewModel: playerViewModel,
                    viewModel: viewModel
                )
                
            case .subfolders:
                List {
                    folderSectionView()
                }
                .listStyle(.insetGrouped)
                
            case .empty:
                Color.clear
                
            }
        }
        .task {
            // 1. Всегда сначала подгружаем подпапки из дерева
            viewModel.loadSubfoldersIfNeeded()
            
            // 2. Если режим — треки, подгружаем сами треки
            if viewModel.displayMode == .tracks {
                await viewModel.loadTracksIfNeeded()
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
