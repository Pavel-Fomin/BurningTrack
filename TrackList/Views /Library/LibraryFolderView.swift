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
    
    @State private var showDeleteAlert = false
    @ObservedObject var playerViewModel: PlayerViewModel
    @ObservedObject var viewModel: LibraryFolderViewModel
    @EnvironmentObject private var sheetManager: SheetManager
    @State private var showDeleteDialog = false
    
    // MARK: - Инициализация зависимостей
    
    init(folder: LibraryFolder,
        trackListViewModel: TrackListViewModel,
        playerViewModel: PlayerViewModel,
        viewModel: LibraryFolderViewModel) {
        self.folder = folder
        self.trackListViewModel = trackListViewModel
        self._playerViewModel = ObservedObject(wrappedValue: playerViewModel)
        self.viewModel = viewModel
    }
    
    var body: some View {
            mainContent
                .task(id: viewModel.folder.url) {
                    viewModel.loadSubfoldersIfNeeded()
                }
                .confirmationDialog(
                    "Удалить папку с iPhone?",
                    isPresented: $showDeleteDialog,
                    titleVisibility: .visible
                ) {
                    Button("Удалить", role: .destructive) {
                        if let url = viewModel.pendingDeleteURL {
                            MusicLibraryManager.shared.removeFolderAndBookmark(url: url)
                            viewModel.pendingDeleteURL = nil
                        }
                    }
                    
                    Button("Отмена", role: .cancel) {
                        viewModel.pendingDeleteURL = nil
                    }
                } message: {
                    Text("Это удалит папку из память Iphone без возможности восстановления")
                }
                .onChange(of: viewModel.pendingDeleteURL) {
                    showDeleteDialog = viewModel.pendingDeleteURL != nil
                }
        }

        // MARK: - Основной контент (если подпапок нет — треки, иначе — список папок)
        
        @ViewBuilder
        private var mainContent: some View {
            if viewModel.subfolders.isEmpty {
                LibraryTracksView(
                    folder: viewModel.folder,
                    trackListViewModel: trackListViewModel,
                    playerViewModel: playerViewModel
                )
            } else {
                List {
                    FolderListView(
                        subfolders: viewModel.subfolders,
                        trackListViewModel: trackListViewModel,
                        playerViewModel: playerViewModel,
                        viewModel: viewModel
                    )
                }
                .listStyle(.insetGrouped)
                .navigationTitle(viewModel.folder.name)
            }
        }
    }
