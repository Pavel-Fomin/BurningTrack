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
    
    @ObservedObject var coordinator: LibraryCoordinator
    @ObservedObject var playerViewModel: PlayerViewModel
    @StateObject private var viewModel: LibraryFolderViewModel
    @State private var scrollTargetID: UUID? = nil
    @State private var revealedTrackID: UUID? = nil
    

    
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

        // Проверяем, есть ли отложенный reveal-трек
        if let revealURL = coordinator.pendingRevealTrackURL {
            self._viewModel = StateObject(
                wrappedValue: LibraryFolderViewModel(folder: folder, pendingReveal: revealURL)
            )
            print("🎯 [FolderView] Передан pendingReveal:", revealURL.lastPathComponent)
        } else {
            self._viewModel = StateObject(wrappedValue: LibraryFolderViewModel(folder: folder))
        }
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
        }
        
        .id(folder.url)
        
        .onReceive(
            coordinator.$pendingRevealTrackURL
                .compactMap { $0 }
        ) { url in
            if url.deletingLastPathComponent().standardizedFileURL
                == viewModel.folder.url.standardizedFileURL {
                
                print("📬 [FolderView] Приняли pendingReveal от координатора:", url.lastPathComponent)
                viewModel.pendingRevealTrackURL = url
                
                // Сбрасываем reveal, чтобы не повторялся при ручном входе
                DispatchQueue.main.async {
                    coordinator.pendingRevealTrackURL = nil
                }
            }
        }
    }
    
    
// MARK: - Секция подпапок
    
    @ViewBuilder
    private func folderSectionView() -> some View {
        Section {
            ForEach(viewModel.subfolders) { subfolder in
                Button(action: {
                    coordinator.openFolder(subfolder)
                }) {
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
