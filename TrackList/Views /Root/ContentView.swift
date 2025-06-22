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
    let trackListViewModel: TrackListViewModel
    let playerViewModel: PlayerViewModel

    var body: some View {
        
        TabView {
            PlayerScreen(
                trackListViewModel: trackListViewModel,
                playerViewModel: playerViewModel
            )
            .tabItem {
                Label("Плеер", systemImage: "play.circle.fill")
            }

            LibraryScreen()
                .tabItem {
                    Label("Фонотека", systemImage: "music.note.list")
                }

            SettingsScreen()
                .tabItem {
                    Label("Настройки", systemImage: "gearshape")
                }
        }
    }
}
