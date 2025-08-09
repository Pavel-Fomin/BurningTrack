//
//  LibraryFolderView.swift
//  TrackList
//
//  Экран вложенной папки
//  Показывает подпапки внутри выбранной папки (folder.subfolders)
//
//  Created by Pavel Fomin on 27.06.2025.
//

import SwiftUI

/// Экран конкретной папки фонотеки.
/// Отвечает ТОЛЬКО за навигацию по подпапкам.
/// Если подпапок нет — рендерит экран треков (LibraryTracksView).
struct LibraryFolderView: View {
    let folder: LibraryFolder
    let trackListViewModel: TrackListViewModel
    @ObservedObject var playerViewModel: PlayerViewModel
    @StateObject private var viewModel: LibraryFolderViewModel

    
// MARK: - Инициализация зависимостей
    
    init(folder: LibraryFolder, trackListViewModel: TrackListViewModel, playerViewModel: PlayerViewModel) {
        self.folder = folder                               // ← ЭТОГО НЕ ХВАТАЛО
        self.trackListViewModel = trackListViewModel
        self._playerViewModel = ObservedObject(wrappedValue: playerViewModel)
        self._viewModel = StateObject(wrappedValue: LibraryFolderViewModel(folder: folder))
    }

    var body: some View {
        Group {
            if viewModel.subfolders.isEmpty {
                // Нет подпапок → экран треков
                LibraryTracksView(
                    folder: viewModel.folder,
                    trackListViewModel: trackListViewModel,
                    playerViewModel: playerViewModel
                )
            } else {
                // Есть подпапки → показываем их
                List { folderSectionView() }
                    .listStyle(.insetGrouped)
                    .navigationTitle(viewModel.folder.name)
            }
        }
        .task(id: viewModel.folder.url) { 
            viewModel.loadSubfoldersIfNeeded()
        }
    }

    
// MARK: - Секция подпапок
    
    @ViewBuilder
    private func folderSectionView() -> some View {
        Section {
            ForEach(viewModel.subfolders) { subfolder in
                NavigationLink(
                    destination: LibraryFolderView(
                        folder: subfolder,
                        trackListViewModel: trackListViewModel,
                        playerViewModel: playerViewModel
                    )
                ) {
                    HStack(spacing: 12) {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text(subfolder.name).lineLimit(1)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
