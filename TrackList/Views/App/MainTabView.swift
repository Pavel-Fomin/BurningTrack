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

    @ObservedObject var playerViewModel: PlayerViewModel

    /// Глобальная ViewModel экспорта передаётся в обе точки запуска операции.
    @ObservedObject var exportProgressViewModel: ExportProgressViewModel

    /// Фабрика production ViewModel для master-flow списка треклистов.
    private static let trackListsViewModelFactory = TrackListsViewModelFactory()

    /// ViewModel master-flow списка треклистов.
    @StateObject private var trackListsVM = Self.trackListsViewModelFactory.make()
    
    
// MARK: - UI
    
    var body: some View {
        TabView(selection: $scene.activeTab) {

// MARK: - Плеер
            
            Tab(
                "Плеер",
                systemImage: "waveform",
                value: ScenePhaseHandler.Tab.player
            ) {
                PlayerScreen(
                    playerViewModel: playerViewModel,
                    exportProgressViewModel: exportProgressViewModel
                )
            }

// MARK: - Фонотека
            
            Tab(
                "Фонотека",
                systemImage: "play.square.stack",
                value: ScenePhaseHandler.Tab.library
            ) {
                LibraryScreen(
                    playerViewModel: playerViewModel,
                    exportProgressViewModel: exportProgressViewModel
                )
            }

// MARK: - Треклисты
            
            Tab(
                "Треклисты",
                systemImage: "list.star",
                value: ScenePhaseHandler.Tab.tracklists
            ) {
                TrackListsScreen(
                    trackListsViewModel: trackListsVM,
                    playerViewModel: playerViewModel,
                    exportProgressViewModel: exportProgressViewModel
                )
            }

// MARK: - Настройки
            
            Tab(
                "Настройки",
                systemImage: "gear",
                value: ScenePhaseHandler.Tab.settings
            ) {
                SettingsScreen(
                    playerViewModel: playerViewModel
                )
            }

// MARK: - Поиск

            Tab(
                "Поиск",
                systemImage: "magnifyingglass",
                value: ScenePhaseHandler.Tab.search,
                role: .search
            ) {
                SearchScreen(
                    playerViewModel: playerViewModel
                )
            }
        }
    }
}
