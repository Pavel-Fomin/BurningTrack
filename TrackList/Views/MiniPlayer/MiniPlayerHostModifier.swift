//
//  MiniPlayerHostModifier.swift
//  TrackList
//
//  Хост мини-плеера для экранов вкладок.
//
//  Роль:
//  - сохраняет внешний API .miniPlayerHost(...);
//  - подключает мини-плеер через единый нижний контейнер;
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

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .bottomPanelsHost(
                trackListViewModel: trackListViewModel,
                playerViewModel: playerViewModel,
                showsTopPanel: false
            ) {
                EmptyView()
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
