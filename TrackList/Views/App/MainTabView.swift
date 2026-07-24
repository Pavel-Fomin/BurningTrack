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

    // MARK: - Зависимости

    @ObservedObject var playerViewModel: PlayerViewModel

    /// Глобальная ViewModel экспорта передаётся в обе точки запуска операции.
    @ObservedObject var exportProgressViewModel: ExportProgressViewModel

    /// Общая ViewModel master-flow треклистов, которой владеет корневой контейнер.
    @ObservedObject var trackListsViewModel: TrackListsViewModel
    /// ViewModel хранит и синхронизирует выбор корневой навигации.
    @ObservedObject var navigationViewModel: MainNavigationViewModel

    /// Состояние системного поиска управляет только глобальной нижней геометрией.
    @Binding var isSearchActive: Bool

    /// Высокий MiniPlayer скрывается только в активном интерфейсе Search-вкладки.
    private var showsMiniPlayer: Bool {
        navigationViewModel.activeTab != .search || isSearchActive == false
    }

    /// Передаёт экранам единый резерв только на время показа высокого MiniPlayer.
    private var globalBottomScrollReserve: CGFloat {
        showsMiniPlayer ? GlobalBottomGeometry.miniPlayerScrollReserve : 0
    }
    
    
// MARK: - Интерфейс
    
    var body: some View {
        TabView(selection: navigationViewModel.tabSelection) {

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
                    trackListsViewModel: trackListsViewModel,
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
