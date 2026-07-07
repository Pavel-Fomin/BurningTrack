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

    @ObservedObject var playerViewModel: PlayerViewModel
    let isVisible: Bool

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .bottomPanelsHost(
                playerViewModel: playerViewModel,
                showsTopPanel: false,
                showsBottomPanel: isVisible
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
        playerViewModel: PlayerViewModel,
        isVisible: Bool = true
    ) -> some View {
        modifier(
            MiniPlayerHostModifier(
                playerViewModel: playerViewModel,
                isVisible: isVisible
            )
        )
    }
}
