//
//  ContentView.swift
//  TrackList
//
//  Корневой контейнер приложения.
//  - содержит TabView (через MainTabView),
//  - поверх показывает тосты и шиты,
//  - НЕ содержит никакой навигационной логики.
//
//  Навигация:
//  — вкладки: ScenePhaseHandler.shared
//  — маршрутизация фонотеки: NavigationCoordinator.shared
//
//  Created by Pavel Fomin on 28.04.2025.
//

import SwiftUI

struct ContentView: View {

    // MARK: - Глобальные менеджеры (живут всё приложение)
    
    @StateObject private var sheetManager = SheetManager.shared
    @StateObject private var trackDetailManager = TrackDetailManager.shared
    
    @ObservedObject private var navigation = NavigationCoordinator.shared
    @ObservedObject private var scene = ScenePhaseHandler.shared

    @ObservedObject var playerViewModel: PlayerViewModel

    /// Единое состояние экспорта передаётся в корневой контейнер вкладок.
    @EnvironmentObject private var exportProgressViewModel: ExportProgressViewModel

    // MARK: - Обёртка для sheet(item:)
    
    private struct IdentifiableTrack: Identifiable {
        let id = UUID()
        let track: any TrackDisplayable
    }

    private var identifiableTrack: IdentifiableTrack? {
        trackDetailManager.track.map { IdentifiableTrack(track: $0) }
    }

    // MARK: - UI
    
    var body: some View {
        MainTabView(
            playerViewModel: playerViewModel,
            exportProgressViewModel: exportProgressViewModel
        )
        .sheetHost(playerManager: playerViewModel.fileOperationPlayerManager)
        .toastHost()
    }
}
