//
//  MiniPlayerWrapperView.swift
//  TrackList
//
//  Обёртка для постоянного размещения мини-плеера.
//
//  Created by Pavel Fomin on 14.07.2026.
//

import SwiftUI

struct MiniPlayerWrapperView: View {

    // MARK: - Input

    /// Неизменяемый feature graph передаёт wrapper-у только готовую точку presentation-сборки.
    let feature: MiniPlayerFeature

    // MARK: - Body

    var body: some View {
        MiniPlayerContainer(feature: feature)
        // Сохраняем горизонтальный внешний отступ мини-плеера от краёв интерфейса.
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
