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
    @State private var didRestoreAccess = false
    
    let playerViewModel: PlayerViewModel
    let trackListViewModel: TrackListViewModel
    @EnvironmentObject var toast: ToastManager

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

                .onAppear {
                    guard !didRestoreAccess else { return }
                    musicLibraryManager.restoreAccess()
                    didRestoreAccess = true
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
                            musicLibraryManager.restoreAccess()
                        }
                    case .failure(let error):
                        print("❌ Ошибка выбора папки: \(error.localizedDescription)")
                    }
                }
            }
            
        }
    }
}
