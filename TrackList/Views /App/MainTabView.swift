//
//  MainTabView.swift
//  TrackList
//
//  Created by Pavel Fomin on 17.07.2025.
//

import Foundation
import SwiftUI

struct MainTabView: View {
    @ObservedObject private var sceneHandler = ScenePhaseHandler.shared
    @ObservedObject var trackListViewModel: TrackListViewModel
    @ObservedObject var playerViewModel: PlayerViewModel
    @Binding var selectedTab: Int

    
    var body: some View {
        TabView(selection: $sceneHandler.activeTab) {
            PlayerScreen(playerViewModel: playerViewModel)
                .tabItem { Label("Плеер", systemImage: "waveform") }
                .tag(ScenePhaseHandler.Tab.player)
                .tag(0)

            LibraryScreen(
                playerViewModel: playerViewModel,
                trackListViewModel: trackListViewModel)
            
                .tabItem { Label("Фонотека", systemImage: "play.square.stack") }
                .tag(ScenePhaseHandler.Tab.library)
                .tag(1)
            

            TrackListsScreen(
                trackListsViewModel: TrackListsViewModel(),
                playerViewModel: playerViewModel)
            
                .tabItem { Label("Треклисты", systemImage: "list.star") }
                .tag(ScenePhaseHandler.Tab.tracklists)
                .tag(2)

            SettingsScreen()
                .tabItem { Label("Настройки", systemImage: "gear") }
                .tag(ScenePhaseHandler.Tab.settings)
                .tag(3)
        }
    }
    
}
