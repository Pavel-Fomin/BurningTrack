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

    /// Состояние системного поиска управляет только глобальной нижней геометрией.
    @State private var isSearchActive = false

    /// Высокий MiniPlayer скрывается только в активном интерфейсе Search-вкладки.
    private var showsMiniPlayer: Bool {
        scene.activeTab != .search || isSearchActive == false
    }

    /// Передаёт экранам единый резерв только на время показа высокого MiniPlayer.
    private var globalBottomScrollReserve: CGFloat {
        showsMiniPlayer ? GlobalBottomGeometry.miniPlayerScrollReserve : 0
    }
    
    
// MARK: - UI
    
    var body: some View {
        TabView(selection: $scene.activeTab) {

// MARK: - Плеер
            
            Tab(
                "Player",
                systemImage: "waveform",
                value: ScenePhaseHandler.Tab.player
            ) {
                PlayerScreen(
                    playerViewModel: playerViewModel,
                    exportProgressViewModel: exportProgressViewModel
                )
                .globalBottomPanelsHost(
                    playerViewModel: playerViewModel,
                    exportProgressViewModel: exportProgressViewModel,
                    showsMiniPlayer: showsMiniPlayer
                )
            }

// MARK: - Фонотека
            
            Tab(
                "Library",
                systemImage: "play.square.stack",
                value: ScenePhaseHandler.Tab.library
            ) {
                LibraryScreen(
                    playerViewModel: playerViewModel,
                    exportProgressViewModel: exportProgressViewModel
                )
                .globalBottomPanelsHost(
                    playerViewModel: playerViewModel,
                    exportProgressViewModel: exportProgressViewModel,
                    showsMiniPlayer: showsMiniPlayer
                )
            }

// MARK: - Треклисты
            
            Tab(
                "Tracklists",
                systemImage: "list.star",
                value: ScenePhaseHandler.Tab.tracklists
            ) {
                TrackListsScreen(
                    trackListsViewModel: trackListsVM,
                    playerViewModel: playerViewModel,
                    exportProgressViewModel: exportProgressViewModel
                )
                .globalBottomPanelsHost(
                    playerViewModel: playerViewModel,
                    exportProgressViewModel: exportProgressViewModel,
                    showsMiniPlayer: showsMiniPlayer
                )
            }

// MARK: - Настройки
            
            Tab(
                "Settings",
                systemImage: "gear",
                value: ScenePhaseHandler.Tab.settings
            ) {
                SettingsScreen(
                    playerViewModel: playerViewModel
                )
                .globalBottomPanelsHost(
                    playerViewModel: playerViewModel,
                    exportProgressViewModel: exportProgressViewModel,
                    showsMiniPlayer: showsMiniPlayer
                )
            }

// MARK: - Поиск

            Tab(
                "Search",
                systemImage: "magnifyingglass",
                value: ScenePhaseHandler.Tab.search,
                role: .search
            ) {
                SearchScreen(
                    playerViewModel: playerViewModel,
                    isSearchActive: $isSearchActive
                )
                .globalBottomPanelsHost(
                    playerViewModel: playerViewModel,
                    exportProgressViewModel: exportProgressViewModel,
                    showsMiniPlayer: showsMiniPlayer
                )
            }
        }
        // Единственный владелец сообщает всем вкладкам размер глобальной перекрывающей зоны.
        .environment(
            \.globalBottomScrollReserve,
            globalBottomScrollReserve
        )
        .animation(
            .easeOut(duration: 0.25),
            value: showsMiniPlayer
        )
    }
}
