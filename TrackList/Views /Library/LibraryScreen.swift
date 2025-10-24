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
    @State private var isShowingFolderPicker = false
    private let musicLibraryManager = MusicLibraryManager.shared
    @State private var path: [LibraryFolder] = []
    @State private var didWarmUp = false
    
    let playerViewModel: PlayerViewModel
    let trackListViewModel: TrackListViewModel
    @EnvironmentObject var toast: ToastManager
    @EnvironmentObject private var navObserver: NavigationObserver
    
    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                VStack(spacing: 0) {
                    if path.isEmpty {
                        LibraryHeaderView {
                            isShowingFolderPicker = true
                        }
                    }
                    
                    MusicLibraryView(
                        path: $path,
                        trackListViewModel: trackListViewModel,
                        playerViewModel: playerViewModel,
                        onAddFolder: {
                            isShowingFolderPicker = true
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                .navigationDestination(for: LibraryFolder.self) { folder in
                    LibraryFolderView(
                        folder: folder,
                        trackListViewModel: trackListViewModel,
                        playerViewModel: playerViewModel
                    )
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
                            Task {
                                await musicLibraryManager.restoreAccessAsync()
                            }
                        }
                    case .failure(let error):
                        print("❌ Ошибка выбора папки: \(error.localizedDescription)")
                    }
                }
            }
        }
        .id(path.first?.id ?? UUID())
        
            // MARK: - Реакция на revealTrack
            .onReceive(navObserver.$requestedTrackURL.compactMap { $0 }) { url in
                // 1) URL папки, где лежит трек
                let folderURL = url.deletingLastPathComponent()
                
                // 2) Ищем папку РЕКУРСИВНО (учитывая подпапки)
                guard let folder = findFolder(for: folderURL,
                                              in: MusicLibraryManager.shared.attachedFolders) else {
                    print("⚠️ Папка для трека не найдена среди прикреплённых")
                    return
                }
                
                // 3) Уже в нужной папке — выходим
                if path.first?.url.standardizedFileURL == folderURL.standardizedFileURL {
                    print("📌 Уже внутри нужной папки: \(folder.name)")
                    return
                }
                
                // 4) Даём SwiftUI дорисовать стек и мгновенно меняем path без дёрганий
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    path.removeAll()
                    path.append(folder)
                    print("➡️ Переход в папку: \(folder.name)")
                }
            }
            
            
            // MARK: - Первый запуск
            .task {
                guard !didWarmUp else { return }
                didWarmUp = true
                print("📡 LibraryScreen готова принимать переходы")
            }
            .onDisappear {
                print("📴 LibraryScreen выгружена")
            }
        }
    }
    
    
    // Рекурсивный поиск папки по URL в прикреплённом дереве
    private func findFolder(for url: URL, in folders: [LibraryFolder]) -> LibraryFolder? {
        for folder in folders {
            // сравниваем «нормализованные» URL, чтобы исключить различия в путях
            if folder.url.standardizedFileURL == url.standardizedFileURL {
                return folder
            }
            if let found = findFolder(for: url, in: folder.subfolders) {
                return found
            }
        }
        return nil
    }

