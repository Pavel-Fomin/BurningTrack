//
//  ContentView.swift
//  TrackList
//
//  Корневой контейнер приложения.
//  - выбирает compact- или regular-компоновку корневой навигации,
//  - поверх показывает тосты и шиты,
//  - владеет общими ViewModel навигации и треклистов.
//
//  Навигация:
//  — основные разделы: MainNavigationViewModel и ScenePhaseHandler.shared
//  — маршрутизация фонотеки: NavigationCoordinator.shared
//
//  Created by Pavel Fomin on 28.04.2025.
//

import SwiftUI

struct ContentView: View {

    // MARK: - Глобальные менеджеры (живут всё приложение)
    
    @StateObject private var sheetManager = SheetManager.shared
    @StateObject private var trackDetailManager = TrackDetailManager.shared
    
    @ObservedObject var playerViewModel: PlayerViewModel

    /// Единое состояние экспорта передаётся в корневой контейнер вкладок.
    @EnvironmentObject private var exportProgressViewModel: ExportProgressViewModel

    /// Размерный класс определяет единственный активный корневой контейнер приложения.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Фабрика создаёт единственную ViewModel master-flow треклистов для обеих компоновок.
    private static let trackListsViewModelFactory = TrackListsViewModelFactory()

    /// Общая ViewModel не пересоздаётся при переходе окна между compact и regular.
    @StateObject private var trackListsViewModel = Self.trackListsViewModelFactory.make()
    /// ViewModel синхронизирует выбор корневой навигации с глобальной активной вкладкой.
    @StateObject private var navigationViewModel = MainNavigationViewModel()
    /// Активность системного поиска влияет только на видимость глобального MiniPlayer.
    @State private var isSearchActive = false

    // MARK: - Обёртка для sheet(item:)
    
    private struct IdentifiableTrack: Identifiable {
        let id = UUID()
        let track: any TrackDisplayable
    }

    private var identifiableTrack: IdentifiableTrack? {
        trackDetailManager.track.map { IdentifiableTrack(track: $0) }
    }

    // MARK: - Интерфейс
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                MainSidebarView(
                    playerViewModel: playerViewModel,
                    exportProgressViewModel: exportProgressViewModel,
                    trackListsViewModel: trackListsViewModel,
                    navigationViewModel: navigationViewModel,
                    isSearchActive: $isSearchActive
                )
            } else {
                MainTabView(
                    playerViewModel: playerViewModel,
                    exportProgressViewModel: exportProgressViewModel,
                    trackListsViewModel: trackListsViewModel,
                    navigationViewModel: navigationViewModel,
                    isSearchActive: $isSearchActive
                )
            }
        }
        .sheetHost(playerManager: playerViewModel.fileOperationPlayerManager)
        .toastHost()
    }
}
