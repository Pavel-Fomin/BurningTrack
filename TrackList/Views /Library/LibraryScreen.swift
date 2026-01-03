//
//  LibraryScreen.swift
//  TrackList
//
//  Вкладка “Фонотека”.
//  Управляет только отображением содержимого фонотеки:
//  — корневой список папок,
//  — содержимое конкретной папки,
//  — обработка события "показать трек во фонотеке".
//
//  Навигация между вкладками → ScenePhaseHandler.
//  Маршруты внутри фонотеки → NavigationCoordinator.libraryRoute.
//
//  Created by Pavel Fomin on 22.06.2025.
//

import SwiftUI

struct LibraryScreen: View {

    // MARK: - Зависимости

    private let musicLibraryManager = MusicLibraryManager.shared

    let playerViewModel: PlayerViewModel
    let trackListViewModel: TrackListViewModel
    
    @ObservedObject private var nav = NavigationCoordinator.shared

    @State private var isShowingFolderPicker = false

    // MARK: - UI

    var body: some View {
        NavigationStack(path: $nav.libraryPath) {
            rootContent
                .libraryToolbar(title: "Фонотека")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .navigationDestination(for: NavigationCoordinator.LibraryRoute.self) { route in
                    destination(for: route)
                }
        }
        .onAppear {
            handlePendingShowTrack()
        }
        // Выбор папки
        .fileImporter(
            isPresented: $isShowingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let folderURL = urls.first {
                    musicLibraryManager.saveBookmark(for: folderURL)
                }
            case .failure(let error):
                print("❌ Ошибка выбора папки: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Root контент

    @ViewBuilder
    private var rootContent: some View {
        MusicLibraryView(
            trackListViewModel: trackListViewModel,
            playerViewModel: playerViewModel,
            onAddFolder: { isShowingFolderPicker = true }
        )
    }

    // MARK: - Navigation destinations

    @ViewBuilder
    private func destination(for route: NavigationCoordinator.LibraryRoute) -> some View {
        switch route {

        case .root:
            rootContent
                .libraryToolbar(title: "Фонотека")

        case .folder(let folderId):
            if let folder = musicLibraryManager.folder(for: folderId) {

                let folderVM = LibraryFolderViewModel(folder: folder)

                LibraryFolderView(
                    trackListViewModel: trackListViewModel,
                    playerViewModel: playerViewModel
                )
                .environmentObject(folderVM)
                .libraryToolbar(title: folder.name)

            } else {
                Text("❌ Папка не найдена")
                    .libraryToolbar(title: "Ошибка")
            }
        }
    }

    // MARK: - Переадресация

    private func handlePendingShowTrack() {
        guard let trackId = nav.consumePendingShowTrackId() else { return }

        Task { @MainActor in
            guard let entry = await TrackRegistry.shared.entry(for: trackId) else {
                print("⚠️ TrackRegistry: не найден trackId = \(trackId)")
                return
            }

            let folderId = entry.folderId

            guard musicLibraryManager.folder(for: folderId) != nil else {
                print("⚠️ MusicLibraryManager: не найдена папка \(folderId)")
                return
            }

            nav.openFolder(folderId)
        }
    }
}
