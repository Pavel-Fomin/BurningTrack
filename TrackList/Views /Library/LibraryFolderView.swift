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
    @State private var scrollTargetID: UUID? = nil
    @State private var revealedTrackID: UUID? = nil

    
// MARK: - Инициализация зависимостей
    
    init(folder: LibraryFolder, trackListViewModel: TrackListViewModel, playerViewModel: PlayerViewModel) {
        self.folder = folder
        self.trackListViewModel = trackListViewModel
        self._playerViewModel = ObservedObject(wrappedValue: playerViewModel)
        self._viewModel = StateObject(wrappedValue: LibraryFolderViewModel(folder: folder))
    }

    var body: some View {
        Group {
            if viewModel.subfolders.isEmpty {
                // Нет подпапок → показываем треки
                LibraryTracksView(
                    folder: viewModel.folder,
                    trackListViewModel: trackListViewModel,
                    playerViewModel: playerViewModel
                )
                .navigationTitle(viewModel.folder.name)
                .navigationBarTitleDisplayMode(.inline)
                
            } else {
                // Есть подпапки → список подпапок
                List { folderSectionView() }
                    .listStyle(.insetGrouped)
                    .navigationTitle(viewModel.folder.name)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task(id: viewModel.folder.url) {
            viewModel.loadSubfoldersIfNeeded()
        }
        .onAppear {
            NavigationCoordinator.shared.notifyLibraryReady(for: folder.url)
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
