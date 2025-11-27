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

    @EnvironmentObject var toast: ToastManager
    @ObservedObject private var nav = NavigationCoordinator.shared

    @State private var isShowingFolderPicker = false

    // MARK: - UI

    var body: some View {

        // Навигация только внутри фонотеки
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .libraryToolbar()
        }

        // Потребляем событие showTrackInLibrary
        .onAppear {
            handlePendingShowTrack()
        }
        .onChange(of: nav.libraryRoute) { _, _ in
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
                    Task { await musicLibraryManager.restoreAccessAsync() }
                }

            case .failure(let error):
                print("❌ Ошибка выбора папки: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Содержимое экрана

    @ViewBuilder
    private var content: some View {
        switch nav.libraryRoute {

        case .root:
            MusicLibraryView(
                trackListViewModel: trackListViewModel,
                playerViewModel: playerViewModel,
                onAddFolder: { isShowingFolderPicker = true }
            )

        case .folder(let folderId):
            if let folder = musicLibraryManager.folder(for: folderId) {
                let vm = LibraryFolderViewModelCache.shared.resolve(for: folder)

                LibraryFolderView(
                    folder: folder,
                    trackListViewModel: trackListViewModel,
                    playerViewModel: playerViewModel
                )
                .environmentObject(vm)

            } else {
                Text("❌ Папка не найдена")
            }
        }
    }

    // MARK: - Переадресация на трек

    /// При получении showTrackInLibrary:
    /// 1. получаем trackId
    /// 2. ищем трек в TrackRegistry → узнаём folderId
    /// 3. открываем папку
    private func handlePendingShowTrack() {
        guard let trackId = nav.consumePendingShowTrackId() else { return }

        Task { @MainActor in
            guard let entry = await TrackRegistry.shared.entry(for: trackId) else {
                print("⚠️ TrackRegistry: не найден trackId = \(trackId)")
                return
            }

            let folderId = entry.folderId

            guard let folder = musicLibraryManager.folder(for: folderId) else {
                print("⚠️ MusicLibraryManager: не найдена папка \(folderId)")
                return
            }

            // 1. Готовим ViewModel папки
            let vm = LibraryFolderViewModelCache.shared.resolve(for: folder)
            vm.pendingRevealTrackID = trackId

            // 2. Открываем папку
            nav.openFolder(folderId)
        }
    }
}
