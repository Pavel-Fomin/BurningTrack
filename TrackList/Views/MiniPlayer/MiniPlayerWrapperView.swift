//
//  MiniPlayerWrapperView.swift
//  TrackList
//
//  Обёртка для постоянного размещения мини-плеера.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import SwiftUI

struct MiniPlayerWrapperView: View {

    // MARK: - Input

    @ObservedObject var playerViewModel: PlayerViewModel

    // MARK: - Body

    var body: some View {
        MiniPlayerView(
            playerViewModel: playerViewModel
        )
        // Сохраняем прежний внешний визуальный отступ мини-плеера.
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
