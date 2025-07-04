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
    @State private var refreshTrigger = false
    let playerViewModel: PlayerViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                
                // Заголовок, как в плеере
                HStack {
                    Text("Фонотека")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Spacer()

                    Button(action: {
                        isShowingFolderPicker = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Переключатель Музыка / Треклисты
                Picker("Раздел", selection: $selectedTab) {
                    Text("Музыка").tag(0)
                    Text("Треклисты").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Контент
                Group {
                    if selectedTab == 0 {
                        MusicLibraryView(playerViewModel: playerViewModel)
                    } else {
                        TrackListLibraryView()
                    }

                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        
        .onAppear {
            print("🧭 LibraryScreen появился — восстанавливаем доступ к папке")
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
                    MusicLibraryManager.shared.saveBookmark(for: folderURL)
                    MusicLibraryManager.shared.restoreAccess()
                }
            case .failure(let error):
                print("❌ Ошибка выбора папки: \(error.localizedDescription)")
            }
        }
    }
}
