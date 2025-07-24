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
                            PlaylistManager.shared.exportCurrentTracks(to: URL(fileURLWithPath: "/"))
                    
                        },
                        onClear: {
                            PlaylistManager.shared.tracks = []
                            PlaylistManager.shared.saveToDisk()
                       }
                    )
                    
                    
// MARK: - Список треков
                    
                    PlayerPlaylistView(playerViewModel: playerViewModel)
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
