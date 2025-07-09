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
    @State private var selectedTab = 0
    @State private var isShowingFolderPicker = false
    private let musicLibraryManager = MusicLibraryManager.shared
    @State private var path: [LibraryFolder] = []
    
    let playerViewModel: PlayerViewModel
    @EnvironmentObject var toast: ToastManager

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                VStack(spacing: 12) {
                    if path.isEmpty {
                        LibraryHeaderView(
                            selectedTab: $selectedTab,
                            onAddFolder: {
                                isShowingFolderPicker = true
                            }
                        )
                    }

                    Group {
                        if selectedTab == 0 {
                            MusicLibraryView(
                                path: $path,
                                playerViewModel: playerViewModel
                            )
                        } else {
                            TrackListLibraryView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if let data = toast.data {
                    ToastView(data: data)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: data.id)
                }
            }
            .navigationDestination(for: LibraryFolder.self) { folder in
                LibraryFolderView(
                    folder: folder,
                    playerViewModel: playerViewModel
                )
            }
            .onAppear {
                musicLibraryManager.restoreAccess()
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
