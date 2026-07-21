//
//  ScreenToolbarTitleView.swift
//  TrackList
//
//  Общий двухстрочный заголовок системной панели навигации.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import SwiftUI

/// Отображает основной заголовок и необязательный вторичный текст в центральной части toolbar.
struct ScreenToolbarTitleView: View {
    /// Основной заголовок экрана.
    let title: String
    /// Вторичный текст, например статистика коллекции.
    let subtitle: String?

    var body: some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
