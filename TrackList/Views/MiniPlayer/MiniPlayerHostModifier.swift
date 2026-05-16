//
//  MiniPlayerHostModifier.swift
//  TrackList
//
//  Хост мини-плеера для экранов вкладок.
//
//  Роль:
//  - подключает MiniPlayerView внутри layout конкретного экрана;
//  - использует safeAreaInset, чтобы мини-плеер не перекрывал системный TabBar;
//  - не содержит логики воспроизведения;
//  - не управляет жестами мини-плеера.
//
//  Created by PavelFomin on 16.05.2026.
//

import SwiftUI

struct MiniPlayerHostModifier: ViewModifier {

    // MARK: - Input

    let trackListViewModel: TrackListViewModel
    @ObservedObject var playerViewModel: PlayerViewModel

    // MARK: - Layout

    private let miniPlayerReservedHeight: CGFloat = 104
    private let miniPlayerHorizontalPadding: CGFloat = 8
    private let miniPlayerBottomPadding: CGFloat = 8

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if playerViewModel.currentTrackDisplayable != nil {
                    Color.clear
                        .frame(height: miniPlayerReservedHeight)
                }
            }
            .overlay(alignment: .bottom) {
                if playerViewModel.currentTrackDisplayable != nil {
                    MiniPlayerView(
                        trackListViewModel: trackListViewModel,
                        playerViewModel: playerViewModel
                    )
                    .padding(.horizontal, miniPlayerHorizontalPadding)
                    .padding(.bottom, miniPlayerBottomPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
    }
}

// MARK: - View extension

extension View {

    /// Подключает мини-плеер к safe area конкретного экрана.
    ///
    /// Используется на уровне screen, а не в ContentView поверх TabView.
    func miniPlayerHost(
        trackListViewModel: TrackListViewModel,
        playerViewModel: PlayerViewModel
    ) -> some View {
        modifier(
            MiniPlayerHostModifier(
                trackListViewModel: trackListViewModel,
                playerViewModel: playerViewModel
            )
        )
    }
}
