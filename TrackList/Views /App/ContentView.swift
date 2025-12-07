//
//  ContentView.swift
//  TrackList
//
//  Корневой контейнер приложения.
//  - содержит TabView (через MainTabView),
//  - поверх показывает мини-плеер,
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
    
    @EnvironmentObject var toast: ToastManager

    @ObservedObject private var navigation = NavigationCoordinator.shared
    @ObservedObject private var scene = ScenePhaseHandler.shared

    @ObservedObject var playerViewModel: PlayerViewModel
    let trackListViewModel: TrackListViewModel

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
        ZStack(alignment: .bottom) {

            // MARK: - Основные вкладки
            
            MainTabView(
                trackListViewModel: trackListViewModel,
                playerViewModel: playerViewModel
            )

            // MARK: - Мини-плеер
            
            if playerViewModel.currentTrackDisplayable != nil {
                MiniPlayerView(
                    trackListViewModel: trackListViewModel,
                    playerViewModel: playerViewModel
                )
                .padding(.horizontal, 8)
                .padding(.bottom, safeTabBarInset)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // MARK: - Тосты
            if let data = toast.data {
                VStack(spacing: 8) {
                    ToastView(data: data)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, toastBottomPadding)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: data.id)
            }
        }

        // MARK: - Подключение SheetHost
        
               .sheetHost(playerManager: playerViewModel.playerManager)
           }
    
    // MARK: - Паддинг для тоста
    
    private var toastBottomPadding: CGFloat {
        let hasMiniPlayer =
        playerViewModel.currentTrackDisplayable != nil
        && scene.activeTab != .tracklists

        let miniPlayerHeight: CGFloat = hasMiniPlayer ? 88 : 0
        let tabBarHeight: CGFloat = 49
        let toastGap: CGFloat = hasMiniPlayer ? 8 : 0
        let spacing: CGFloat = 12

        return miniPlayerHeight + toastGap + tabBarHeight + spacing
    }

    // MARK: - Safe area для мини-плеера (Dynamic Island / Face ID / SE)
    private var safeTabBarInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?
            .safeAreaInsets.bottom ?? 49
    }
}
