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
    @ObservedObject private var sceneHandler = ScenePhaseHandler.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // MARK: - Контент
                ZStack {
                    if case .root = coordinator.state {
                        MusicLibraryView(
                            trackListViewModel: trackListViewModel,
                            playerViewModel: playerViewModel,
                            onAddFolder: { isShowingFolderPicker = true },
                            coordinator: coordinator
                        )
                        .id("root")
                        .libraryTransition()
                    }

                    if case .folder(let folder) = coordinator.state {
                        LibraryFolderView(
                            folder: folder,
                            coordinator: coordinator,
                            trackListViewModel: trackListViewModel,
                            playerViewModel: playerViewModel
                        )
                        .id(folder.url)
                        .libraryTransition()
                    }

                    if case .tracks(let folder) = coordinator.state {
                        LibraryFolderView(
                            folder: folder,
                            coordinator: coordinator,
                            trackListViewModel: trackListViewModel,
                            playerViewModel: playerViewModel
                        )
                        .id("tracks-\(folder.url.path)")
                        .libraryTransition()
                    }
                }
                .animation(.easeInOut(duration: 0.40), value: coordinator.stateID)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
            // Тулбар
            .libraryToolbar(
                coordinator: coordinator,
                onAddFolder: { isShowingFolderPicker = true }
            )
        }
    
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
            .onReceive(sceneHandler.$repeatedTabSelection.compactMap { $0 }) { tab in
                if tab == .library {
                    print("🔁 Повторное нажатие на вкладку Фонотека — возвращаемся в корень")
                    coordinator.resetToRoot()
                }
            }
            .task {
                if let url = NavigationCoordinator.shared.pendingReveal {
                    print("📨 [LibraryScreen] Отложенный reveal обнаружен при старте:", url.lastPathComponent)
                    NavigationCoordinator.shared.pendingReveal = nil
                    await coordinator.revealTrack(at: url, in: musicLibraryManager.attachedFolders)
                }
            }
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
