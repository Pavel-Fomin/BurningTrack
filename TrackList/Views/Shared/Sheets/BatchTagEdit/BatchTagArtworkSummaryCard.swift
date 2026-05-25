//
//  BatchTagArtworkSummaryCard.swift
//  TrackList
//
//  Карточка со сводной информацией по обложкам выбранных треков.
//
//  Created by Pavel Fomin on 25.05.2026.
//

import SwiftUI

/// Карточка со сводной информацией по обложкам выбранных треков.
struct BatchTagArtworkSummaryCard: View {
    /// Сводная информация по обложкам.
    let summary: BatchTagArtworkPreviewSummary
    /// Выбрана ли карточка.
    let isSelected: Bool
    /// Обработчик выбора карточки.
    let onSelect: () -> Void
    /// Обработчик действия из меню.
    let onMenuAction: (BatchTagArtworkMenuAction, BatchTagArtworkActionTarget) -> Void
    var body: some View {
        ZStack(alignment: .topTrailing) {
            background
            Image(systemName: "square.stack")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 150, height: 150)
            menuButton
                .padding(8)
        }
        .frame(width: 150, height: 150)
        .onTapGesture {
            onSelect()
        }
        .batchTagArtworkSelection(isSelected)
    }
    /// Кнопка меню действий.
    private var menuButton: some View {
        BatchTagArtworkCardMenu {
            onMenuAction($0, .summary)
        }
    }
    /// Фон карточки.
    private var background: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }
}
