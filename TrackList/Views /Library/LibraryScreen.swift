//
//  LibraryScreen.swift
//  TrackList
//
//  Вкладка “Фонотека”
//
//  Created by Pavel Fomin on 22.06.2025.
//


import SwiftUI

struct LibraryScreen: View {
    private let musicLibraryManager = MusicLibraryManager.shared
    let playerViewModel: PlayerViewModel
    let trackListViewModel: TrackListViewModel

    @State private var isShowingFolderPicker = false
    @State private var didWarmUp = false
    @StateObject private var coordinator = LibraryCoordinator()
    @EnvironmentObject var toast: ToastManager

    var body: some View {
            VStack(spacing: 0) {
                // MARK: - Заголовок
                LibraryHeaderView(
                    onAddFolder: { isShowingFolderPicker = true },
                    coordinator: coordinator
                )
                .zIndex(1)

                // MARK: - Контент
                Group {
                    switch coordinator.state {
                    case .root:
                        MusicLibraryView(
                            trackListViewModel: trackListViewModel,
                            playerViewModel: playerViewModel,
                            onAddFolder: { isShowingFolderPicker = true },
                            coordinator: coordinator
                        )
                        .id("root")

                    case .folder(let folder):
                        LibraryFolderView(
                            folder: folder,
                            coordinator: coordinator,
                            trackListViewModel: trackListViewModel,
                            playerViewModel: playerViewModel
                        )
                        .id(folder.url)

                    case .tracks(let folder):
                        LibraryFolderView(
                            folder: folder,
                            coordinator: coordinator,
                            trackListViewModel: trackListViewModel,
                            playerViewModel: playerViewModel
                        )
                        .id("tracks-\(folder.url.path)")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
            .ignoresSafeArea(edges: .bottom)
            .onReceive(
                NavigationCoordinator.shared.$pendingReveal
                    .compactMap { $0 }
                    .removeDuplicates()
            ) { url in
                print("📨 Получен reveal-сигнал для:", url.lastPathComponent)
                NavigationCoordinator.shared.pendingReveal = nil

                Task { @MainActor in
                    await coordinator.revealTrack(
                        at: url,
                        in: musicLibraryManager.attachedFolders
                    )
                }
            }

        // MARK: - Импорт папок
        .fileImporter(
            isPresented: $isShowingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let folderURL = urls.first {
                    musicLibraryManager.saveBookmark(for: folderURL)
                    Task { await musicLibraryManager.restoreAccessAsync() }
                }
            case .failure(let error):
                print("❌ Ошибка выбора папки: \(error.localizedDescription)")
            }
        }

        .task {
            if !didWarmUp {
                didWarmUp = true
                print("📡 LibraryScreen активна")
            }
        }
    }
    
}
