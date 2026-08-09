//
//  BatchTagArtworkSummaryCard.swift
//  TrackList
//
//  Показывает сводную карточку artwork из presentation state.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import SwiftUI

/// Карточка всех выбранных треков без знаний о mutable artwork state.
struct BatchTagArtworkSummaryCard: View {
    /// Готовые отображаемые данные summary-карточки.
    let state: BatchTagEditArtworkSummaryScreenState
    /// Передаёт выбор цели наружу.
    let onSelect: () -> Void
    /// Передаёт выбранное действие меню наружу.
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
                sizeBadge.padding(.bottom, 8)
            }
            .frame(width: 150, height: 150)
            BatchTagArtworkCardMenu {
                onMenuAction($0, .summary)
            }
            .padding(8)
        }
        .frame(width: 150, height: 150)
        .onTapGesture(perform: onSelect)
        .batchTagArtworkSelection(state.isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(BatchTagEditPresentationText.allSelectedTracksAccessibilityLabel)
        .accessibilityValue(
            BatchTagEditPresentationText.selectedTracksAccessibilityValue(
                for: state.selectedCount
            )
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            onSelect()
        }
    }

    /// Badge получает уже отформатированное Presenter-ом значение.
    private var sizeBadge: some View {
        Text(state.formattedArtworkSize)
            .font(.caption2)
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.55))
            .clipShape(Capsule())
    }

    /// Сохраняет существующую геометрию summary-карточки.
    private var background: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }
}
