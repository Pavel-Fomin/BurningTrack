//
//  BatchTagArtworkPreviewCard.swift
//  TrackList
//
//  Показывает карточку artwork из готового presentation state.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import SwiftUI
import UIKit

/// Карточка одной artwork без обращения к ArtworkProvider или runtime store.
struct BatchTagArtworkPreviewCard: View {
    /// Полностью подготовленные Presenter-ом данные карточки.
    let state: BatchTagEditArtworkCardScreenState
    /// Передаёт выбор конкретного трека наружу.
    let onSelect: () -> Void
    /// Передаёт выбранное действие меню наружу.
    let onMenuAction: (BatchTagArtworkMenuAction) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            artworkContent
            VStack {
                Spacer()
                sizeBadge.padding(.bottom, 8)
            }
            .frame(width: 150, height: 150)
            BatchTagArtworkCardMenu(onAction: onMenuAction)
                .padding(8)
        }
        .onTapGesture(perform: onSelect)
        .batchTagArtworkSelection(state.isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            BatchTagEditPresentationText.artworkPreviewAccessibilityLabel(
                title: state.title,
                hasArtwork: state.hasArtwork
            )
        )
        .accessibilityValue(state.isSelected ? String(localized: "Selected") : "")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            onSelect()
        }
    }

    /// Использует общий presentation-компонент только с готовым ArtworkRequest.
    private var artworkContent: some View {
        ArtworkPreparationView(request: state.artworkRequest) { image in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 150, height: 150)
                .clipShape(previewShape)
        } placeholder: {
            placeholder
        }
    }

    /// Badge не форматирует domain-данные и отображает готовый текст.
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

    /// Показывает сохранённый placeholder, если artwork отсутствует или не декодирована.
    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
            Image(systemName: "music.note")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 150, height: 150)
        .clipShape(previewShape)
    }

    /// Геометрия artwork остаётся идентичной прежней карточке.
    private var previewShape: some Shape {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }
}
