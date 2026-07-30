//
//  TrackArtworkBadgeView.swift
//  TrackList
//
//  Неитерактивный бейдж поверх обложки трека.
//
//  Created by Pavel Fomin on 30.07.2026.
//

import SwiftUI

/// Рисует единый визуальный знак источника или «Избранного» по готовому presentation-состоянию.
struct TrackArtworkBadgeView: View {

    // MARK: - Входные данные

    let state: TrackArtworkBadgeState

    // MARK: - Интерфейс

    @ViewBuilder
    var body: some View {
        switch state {
        case .hidden:
            EmptyView()

        case .favorite:
            badge(
                symbolName: "heart.fill",
                backgroundColor: .red,
                accessibilityLabel: String(localized: "artwork.badge.favorite")
            )

        case .source(let source, let isFavorite):
            sourceBadge(
                source,
                isFavorite: isFavorite
            )
        }
    }

    /// Выбирает логотип внешнего источника, сохраняя его приоритет над символом «Избранного».
    @ViewBuilder
    private func sourceBadge(
        _ source: TrackArtworkSourceBadge,
        isFavorite: Bool
    ) -> some View {
        switch source {
        case .apple:
            badge(
                symbolName: "apple.logo",
                // Красный фон передаёт состояние «Избранного», не добавляя вторую иконку.
                backgroundColor: isFavorite ? .red : .black,
                accessibilityLabel: String(
                    localized: isFavorite
                        ? "artwork.badge.apple.favorite"
                        : "artwork.badge.apple"
                )
            )
        }
    }

    /// Централизованно задаёт размер, символ и оформление всех вариантов бейджа.
    private func badge(
        symbolName: String,
        backgroundColor: Color,
        accessibilityLabel: String
    ) -> some View {
        Image(systemName: symbolName)
            .font(.system(size: 10, weight: .bold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(backgroundColor, in: Circle())
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isImage)
    }
}

#if DEBUG
#Preview("Бейдж отсутствует") {
    Circle()
        .fill(.gray.opacity(0.3))
        .frame(width: 48, height: 48)
        .overlay(alignment: .bottomTrailing) {
            TrackArtworkBadgeView(state: .hidden)
                .offset(x: 2, y: 2)
        }
        .padding()
}

#Preview("Избранное") {
    Circle()
        .fill(.gray.opacity(0.3))
        .frame(width: 48, height: 48)
        .overlay(alignment: .bottomTrailing) {
            TrackArtworkBadgeView(state: .favorite)
                .offset(x: 2, y: 2)
        }
        .padding()
}

#Preview("Apple") {
    Circle()
        .fill(.gray.opacity(0.3))
        .frame(width: 48, height: 48)
        .overlay(alignment: .bottomTrailing) {
            TrackArtworkBadgeView(
                state: .source(.apple, isFavorite: false)
            )
            .offset(x: 2, y: 2)
        }
        .padding()
}

#Preview("Apple в Избранном") {
    Circle()
        .fill(.gray.opacity(0.3))
        .frame(width: 48, height: 48)
        .overlay(alignment: .bottomTrailing) {
            TrackArtworkBadgeView(
                state: .source(.apple, isFavorite: true)
            )
            .offset(x: 2, y: 2)
        }
        .padding()
}
#endif
