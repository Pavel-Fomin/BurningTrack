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
    @State private var miniPlayerHeight: CGFloat = 0
    let trackListViewModel: TrackListViewModel
    
    var body: some View {
        MiniPlayerWrapperView(
            playerViewModel: playerViewModel,
            trackListViewModel: trackListViewModel
        ) {
            ZStack(alignment: .bottom) {
                MainTabView(
                    trackListViewModel: trackListViewModel,
                    playerViewModel: playerViewModel
                )
                
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
        }
        .onAppear { Haptics.shared.warmup() }
        
        .sheet(item: $sheetManager.trackActionsSheet, onDismiss: {
            sheetManager.highlightedTrackID = nil
        }) { data in
            // базовый расчёт высоты
            let base = CGFloat(data.actions.count) * 56 + 8
            // добавляем «воздух» сверху, если кнопок мало
            let adjusted = data.actions.count <= 2 ? base + 28 : base

            TrackActionSheet(
                track: data.track,
                context: data.context,
                actions: data.actions,
                onAction: { action in
                    // Обработчик выбранного действия
                    print("Выбрано действие: \(action)")
                }
            )
            .presentationDetents([.height(adjusted)])
            
        }
    }
    
// MARK: - Тост
    
    private var toastBottomPadding: CGFloat {
        let hasMiniPlayer = playerViewModel.currentTrackDisplayable != nil && selectedTab != 2
        let miniPlayerHeight: CGFloat = hasMiniPlayer ? 88 : 0
        let tabBarHeight: CGFloat = 49
        let toastGap: CGFloat = hasMiniPlayer ? 8 : 0
        let spacing: CGFloat = 12
        return miniPlayerHeight + toastGap + tabBarHeight + spacing
    }
}
