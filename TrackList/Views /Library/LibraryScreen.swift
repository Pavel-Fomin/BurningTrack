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
                    switch coordinator.state {
                    case .root:
                        MusicLibraryView(
                            trackListViewModel: trackListViewModel,
                            playerViewModel: playerViewModel,
                            onAddFolder: { isShowingFolderPicker = true },
                            coordinator: coordinator
                        )
                        .libraryTransition()

                    case .folder(let folder):
                        LibraryFolderView(
                            folder: folder,
                            coordinator: coordinator,
                            trackListViewModel: trackListViewModel,
                            playerViewModel: playerViewModel
                        )
                        .libraryTransition()

                    case .tracks(let folder):
                        LibraryFolderView(
                            folder: folder,
                            coordinator: coordinator,
                            trackListViewModel: trackListViewModel,
                            playerViewModel: playerViewModel
                        )
                        .libraryTransition()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
            // Тулбар
            .libraryToolbar(
                coordinator: coordinator,
                onAddFolder: { isShowingFolderPicker = true }
            )
        }
    
        // открыть вкладку «Фонотека»
        .onReceive(
            NavigationCoordinator.shared.$pendingRevealTrackID
                .compactMap { $0 }
                .removeDuplicates()
        ) { trackId in
            Task { @MainActor in
                let folders = musicLibraryManager.attachedFolders
                await coordinator.revealTrack(trackId: trackId, in: folders)
            }
        }
        /*.onReceive(sceneHandler.$repeatedTabSelection.compactMap { $0 }) { tab in
            guard coordinator.pendingRevealTrackID == nil else {
                // если в процессе REVEAL — запрещаем resetToRoot
                print("⛔ Игнорируем repeatedTabSelection, идёт REVEAL")
                return
            }

            if tab == .library {
                print("🔁 Повторное нажатие на вкладку Фонотека — возвращаемся в корень")
                coordinator.resetToRoot()
            }
        }*/
            
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
