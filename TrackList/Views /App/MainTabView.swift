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

    var body: some View {
        TabView {
            PlayerScreen(playerViewModel: playerViewModel)
                .tabItem {
                    Label("Плеер", systemImage: "waveform")
                }

            LibraryScreen(
                playerViewModel: playerViewModel,
                trackListViewModel: trackListViewModel
            )
                .tabItem {
                    Label("Фонотека", systemImage: "play.square.stack")
                }

            TrackListsScreen(
                trackListViewModel: trackListViewModel,
                playerViewModel: playerViewModel
            )
                .tabItem {
                    Label("Треклисты", systemImage: "list.star")
                }

            SettingsScreen()
                .tabItem {
                    Label("Настройки", systemImage: "gear")
                }
        }
    }
}
