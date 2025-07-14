//
//  ContentView.swift
//  TrackList
//
// 
//
//  Created by Pavel Fomin on 28.04.2025.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    let trackListViewModel: TrackListViewModel
    @State private var selectedTab: Int = 0
    @EnvironmentObject var toast: ToastManager
    @State private var miniPlayerHeight: CGFloat = 0
    
    var body: some View {
        MiniPlayerWrapperView(
            playerViewModel: playerViewModel,
            trackListViewModel: trackListViewModel
        ) {
            ZStack(alignment: .bottom) {
                TabView(selection: $selectedTab) {
                    
                    
// MARK: - Плеер
                    PlayerScreen(
                        trackListViewModel: trackListViewModel,
                        playerViewModel: playerViewModel
                    )
                    .tabItem {
                        Label("Плеер", systemImage: "play.circle.fill")
                    }
                    .tag(0)
                    
// MARK: - Фонотека
                    LibraryScreen(playerViewModel: playerViewModel)
                        .tabItem {
                            Label("Фонотека", systemImage: "music.note.list")
                        }
                        .tag(1)
                    
// MARK: - Настройки
                    SettingsScreen()
                        .tabItem {
                            Label("Настройки", systemImage: "gearshape")
                        }
                        .tag(2)
                }
                .onPreferenceChange(MiniPlayerHeightPreferenceKey.self) { value in
                    miniPlayerHeight = value
                }
                
// MARK: - Toast поверх всех вкладок
                if let data = toast.data {
                    VStack(spacing: 8) {
                        ToastView(data: data)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, toastBottomPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: data.id)
                }
            }
        }
    }
    
    
// MARK: - Тост
    private var toastBottomPadding: CGFloat {
        let hasMiniPlayer = playerViewModel.currentTrackDisplayable != nil && selectedTab != 2
        let miniPlayerHeight: CGFloat = hasMiniPlayer ? 88 : 0
        let tabBarHeight: CGFloat = 49
        let toastGap: CGFloat = hasMiniPlayer ? 8 : 0
        let spacing: CGFloat = 12
        return miniPlayerHeight + toastGap + tabBarHeight + spacing
    }
}
