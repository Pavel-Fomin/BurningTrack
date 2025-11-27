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
//  - reveal/переадресация → обрабатывается В LibraryScreen, не здесь.
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
    @StateObject private var viewModel: LibraryFolderViewModel

    // MARK: - Инициализация

    init(
        folder: LibraryFolder,
        trackListViewModel: TrackListViewModel,
        playerViewModel: PlayerViewModel
    ) {
        self.folder = folder
        self.trackListViewModel = trackListViewModel
        self._playerViewModel = ObservedObject(wrappedValue: playerViewModel)

        // Все кэши/VM создаются через LibraryFolderViewModelCache
        self._viewModel = StateObject(
            wrappedValue: LibraryFolderViewModelCache.shared.resolve(for: folder)
        )
    }

    // MARK: - UI

    var body: some View {
        Group {
            if viewModel.subfolders.isEmpty {

                // Папка без подпапок → показываем треки
                LibraryTracksView(
                    folder: viewModel.folder,
                    trackListViewModel: trackListViewModel,
                    playerViewModel: playerViewModel,
                    viewModel: viewModel
                )
                .navigationTitle(viewModel.folder.name)
                .navigationBarTitleDisplayMode(.inline)

            } else {

                // Есть подпапки → показываем список подпапок
                List {
                    folderSectionView()
                }
                .listStyle(.insetGrouped)
                .navigationTitle(viewModel.folder.name)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task {
            // Загружаем подпапки (лениво)
            viewModel.loadSubfoldersIfNeeded()
        }
    }

    // MARK: - Список подпапок

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
                    // Новый чистый маршрут
                    nav.openFolder(subfolder.id)
                }
            }
        }
    }
}
