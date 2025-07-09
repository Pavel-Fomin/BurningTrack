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
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                
                // Плеер
                ZStack(alignment: .bottom) {
                    PlayerScreen(
                        trackListViewModel: trackListViewModel,
                        playerViewModel: playerViewModel
                    )
                    if playerViewModel.currentTrackDisplayable != nil && selectedTab != 2 {
                        MiniPlayerView(
                            playerViewModel: playerViewModel,
                            trackListViewModel: trackListViewModel
                            
                        )
                        .padding(.bottom, 8)
                    }
                }
                .tabItem {
                    Label("Плеер", systemImage: "play.circle.fill")
                }
                .tag(0)
                
                
                // Фонотека
                ZStack(alignment: .bottom) {
                    LibraryScreen(playerViewModel: playerViewModel)
                    if playerViewModel.currentTrackDisplayable != nil && selectedTab != 2 {
                        MiniPlayerView(
                            playerViewModel: playerViewModel,
                            trackListViewModel: trackListViewModel
                        )
                        .padding(.bottom, 8)
                    }
                }
                .tabItem {
                    Label("Фонотека", systemImage: "music.note.list")
                }
                .tag(1)
                
                
                // Настройки
                ZStack(alignment: .bottom) {
                    SettingsScreen()
                    if playerViewModel.currentTrackDisplayable != nil && selectedTab != 2 {
                        MiniPlayerView(
                            playerViewModel: playerViewModel,
                            trackListViewModel: trackListViewModel
                        )
                        .padding(.bottom, 8)
                    }
                }
                .tabItem {
                    Label("Настройки", systemImage: "gearshape")
                }
                .tag(2)
                
            }
            .onPreferenceChange(MiniPlayerHeightPreferenceKey.self) { value in
                miniPlayerHeight = value
            }
            
            
            // Toast поверх всех вкладок
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
    private var toastBottomPadding: CGFloat {
        let hasMiniPlayer = playerViewModel.currentTrackDisplayable != nil && selectedTab != 2
        let miniPlayerHeight: CGFloat = hasMiniPlayer ? 88 : 0
        let tabBarHeight: CGFloat = 49
        let toastGap: CGFloat = hasMiniPlayer ? 8 : 0
        let spacing: CGFloat = 12
        return miniPlayerHeight + toastGap + tabBarHeight + spacing
    }
}
        

