//
//  ContentView.swift
//  TrackList
//
//  Основное view приложения
//
//  Created by Pavel Fomin on 28.04.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var sheetManager = SheetManager.shared
    @ObservedObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var toast: ToastManager
    @State private var selectedTab: Int = 0
    let trackListViewModel: TrackListViewModel
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Основные вкладки
            MainTabView(
                trackListViewModel: trackListViewModel,
                playerViewModel: playerViewModel
            )

            // Мини-плеер
            if playerViewModel.currentTrackDisplayable != nil {
                MiniPlayerView(
                    trackListViewModel: trackListViewModel,
                    playerViewModel: playerViewModel
                )
                .padding(.horizontal, 8)
                .padding(.bottom, safeTabBarInset)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Тост-уведомления
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

        .sheet(item: $sheetManager.trackActionsSheet, onDismiss: {
            sheetManager.highlightedTrackID = nil
        }) { data in
            let base = CGFloat(data.actions.count) * 56 + 8
            let adjusted = data.actions.count <= 2 ? base + 28 : base

            TrackActionSheet(
                track: data.track,
                context: data.context,
                actions: data.actions,
                onAction: { action in
                    print("Выбрано действие: \(action)")
                }
            )
            .presentationDetents([.height(adjusted)])
        }
    }

    
// MARK: - Тост-паддинг
    private var toastBottomPadding: CGFloat {
        let hasMiniPlayer = playerViewModel.currentTrackDisplayable != nil && selectedTab != 2
        let miniPlayerHeight: CGFloat = hasMiniPlayer ? 88 : 0
        let tabBarHeight: CGFloat = 49
        let toastGap: CGFloat = hasMiniPlayer ? 8 : 0
        let spacing: CGFloat = 12
        return miniPlayerHeight + toastGap + tabBarHeight + spacing
    }
}


// MARK: - Вычесляемое свойство для Dynamic Island, Face ID, iPhone SE и т.д.
private var safeTabBarInset: CGFloat {
    UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
        .first?
        .safeAreaInsets.bottom ?? 49
}
