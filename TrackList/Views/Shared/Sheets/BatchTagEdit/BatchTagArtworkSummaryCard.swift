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
    /// Общий размер preview-обложек в байтах с учётом несохранённых изменений.
    let totalArtworkSizeBytesForPreview: Int
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
            VStack {
                Spacer()
                sizeBadge
                    .padding(.bottom, 8)
            }
            .frame(width: 150, height: 150)
            menuButton
                .padding(8)
        }
        .frame(width: 150, height: 150)
        .onTapGesture {
            onSelect()
        }
        .batchTagArtworkSelection(isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            BatchTagEditPresentationText.allSelectedTracksAccessibilityLabel
        )
        .accessibilityValue(
            BatchTagEditPresentationText.selectedTracksAccessibilityValue(
                for: summary.selectedCount
            )
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            onSelect()
        }
    }

    /// Форматированный общий размер preview-обложек.
    private var formattedTotalArtworkSize: String {
        BatchTagArtworkSizeFormatter.string(from: totalArtworkSizeBytesForPreview)
    }

    /// Badge с общим размером обложек.
    private var sizeBadge: some View {
        Text(formattedTotalArtworkSize)
            .font(.caption2)
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.55))
            .clipShape(Capsule())
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
