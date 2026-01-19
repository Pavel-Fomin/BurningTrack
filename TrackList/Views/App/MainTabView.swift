//
//  MainTabView.swift
//  TrackList
//
//  Корневой контейнер с TabView.
//  — читает активную вкладку из ScenePhaseHandler,
//  — отображает основные разделы приложения.
//
//  NavigationCoordinator НЕ хранит вкладки — он переключает их через ScenePhaseHandler.
//
//  Created by Pavel Fomin on 17.07.2025.
//

import SwiftUI
import Foundation

struct MainTabView: View {

    // MARK: - Global managers

    @ObservedObject private var scene = ScenePhaseHandler.shared
    @ObservedObject private var nav = NavigationCoordinator.shared

    @ObservedObject var trackListViewModel: TrackListViewModel
    @ObservedObject var playerViewModel: PlayerViewModel
    
    @StateObject private var trackListsVM = TrackListsViewModel()
    
    
// MARK: - UI
    
    var body: some View {
        TabView(selection: $scene.activeTab) {

// MARK: - Плеер
            
            PlayerScreen(playerViewModel: playerViewModel)
                .tabItem { Label("Плеер", systemImage: "waveform") }
                .tag(ScenePhaseHandler.Tab.player)

// MARK: - Фонотека
            
            LibraryScreen(
                playerViewModel: playerViewModel,
                trackListViewModel: trackListViewModel
            )
                .tabItem { Label("Фонотека", systemImage: "play.square.stack") }
                .tag(ScenePhaseHandler.Tab.library)

// MARK: - Треклисты
            
            TrackListsScreen(
                trackListsViewModel: trackListsVM,
                playerViewModel: playerViewModel
            )
                .tabItem { Label("Треклисты", systemImage: "list.star") }
                .tag(ScenePhaseHandler.Tab.tracklists)

// MARK: - Настройки
            
            SettingsScreen()
                .tabItem { Label("Настройки", systemImage: "gear") }
                .tag(ScenePhaseHandler.Tab.settings)
        }
    }
}
