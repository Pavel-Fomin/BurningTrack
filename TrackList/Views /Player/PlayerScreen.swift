//
//  PlayerScreen.swift
//  TrackList
//
//  Вкладка “Плеер”
//
//  Created by Pavel Fomin on 22.06.2025.
//

import SwiftUI

struct PlayerScreen: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @State private var showImporter = false
    @State private var isShowingExportPicker = false
    
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(.systemBackground)
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    
                    
// MARK: - Хедер
                    
                    PlayerHeaderView(
                        trackCount: PlaylistManager.shared.tracks.count,
                        onSave: {
                            PlaylistManager.shared.saveToDisk()
                        },
                        onExport: {
                            isShowingExportPicker = true
                        },
                        onClear: {
                            PlaylistManager.shared.tracks = []
                            PlaylistManager.shared.saveToDisk()
                       }
                    )
                    
                    
// MARK: - Список треков
                    
                    PlayerPlaylistView(playerViewModel: playerViewModel)
                }
                
                
// MARK: - Экспорт треков
                
                .sheet(isPresented: $isShowingExportPicker) {
                    ExportWrapper { folderURL in
                        PlaylistManager.shared.exportCurrentTracks(to: folderURL)
                    }
                }
                
                
// MARK: - Импорт треков
                
                .fileImporter(
                    isPresented: $showImporter,
                    allowedContentTypes: [.audio],
                    allowsMultipleSelection: true
                ) { result in
                    Task {
                        switch result {
                        case .success(let urls):
                            await PlaylistManager.shared.importTracks(from: urls)

                        case .failure(let error):
                            print("❌ Ошибка при импорте треков в плеер: \(error.localizedDescription)")
                        }
                    }
                }
                
                
// MARK: - Инициализация при старте
                
                .onAppear {
                    let startTime = Date()
                    let loadTime = Date().timeIntervalSince(startTime)
                    print("Приложение готово к работе за \(String(format: "%.2f", loadTime)) сек")
                    
                }
            }
        }
    }
}
