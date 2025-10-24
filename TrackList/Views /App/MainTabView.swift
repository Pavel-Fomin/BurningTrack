//
//  MainTabView.swift
//  TrackList
//
//  Created by Pavel Fomin on 17.07.2025.
//

import Foundation
import SwiftUI

struct MainTabView: View {
    @ObservedObject var trackListViewModel: TrackListViewModel
    @ObservedObject var playerViewModel: PlayerViewModel
    @Binding var selectedTab: Int          // ← добавили

    var body: some View {
        TabView(selection: $selectedTab) { // ← привязали selection
            PlayerScreen(playerViewModel: playerViewModel)
                .tabItem { Label("Плеер", systemImage: "waveform") }
                .tag(0)                    // ← тег

            LibraryScreen(
                playerViewModel: playerViewModel,
                trackListViewModel: trackListViewModel
            )
                .tabItem { Label("Фонотека", systemImage: "play.square.stack") }
                .tag(1)

            TrackListsScreen(
                trackListViewModel: trackListViewModel,
                playerViewModel: playerViewModel
            )
                .tabItem { Label("Треклисты", systemImage: "list.star") }
                .tag(2)

            SettingsScreen()
                .tabItem { Label("Настройки", systemImage: "gear") }
                .tag(3)
        }
    }
}
