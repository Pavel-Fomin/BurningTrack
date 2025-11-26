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

struct LibraryFolderView: View {
    let folder: LibraryFolder
    let trackListViewModel: TrackListViewModel
    
    @ObservedObject var coordinator: LibraryCoordinator
    @ObservedObject var playerViewModel: PlayerViewModel
    @StateObject private var viewModel: LibraryFolderViewModel
    
// MARK: - Инициализация зависимостей
    
    init(
        folder: LibraryFolder,
        coordinator: LibraryCoordinator,
        trackListViewModel: TrackListViewModel,
        playerViewModel: PlayerViewModel
    ) {
        self.folder = folder
        self.coordinator = coordinator
        self.trackListViewModel = trackListViewModel
        self._playerViewModel = ObservedObject(wrappedValue: playerViewModel)

        self._viewModel = StateObject(
            wrappedValue: LibraryFolderViewModelCache.shared.resolve(for: folder)
        )
    }

    var body: some View {
        Group {
            if viewModel.subfolders.isEmpty {
                
                // Нет подпапок → показываем треки
                LibraryTracksView(
                    folder: viewModel.folder,
                    trackListViewModel: trackListViewModel,
                    coordinator: coordinator,
                    playerViewModel: playerViewModel,
                    viewModel: viewModel
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
            if let revealId = coordinator.pendingRevealTrackID {
                    applyRevealIfNeeded(revealId)
                }
            }
        
        .id(folder.url)
    }
    
// MARK: - Reveal обработка
    private func applyRevealIfNeeded(_ trackId: UUID) {
        if viewModel.trackSections.flatMap({ $0.tracks }).contains(where: { $0.id == trackId }) {
            viewModel.pendingRevealTrackID = trackId
            coordinator.pendingRevealTrackID = nil
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
                    Text(subfolder.name).lineLimit(1)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    coordinator.openFolder(subfolder)
                }
            }
        }
    }
}
