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

    var body: some View {
        TabView(selection: $selectedTab) {
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
        }
    }

