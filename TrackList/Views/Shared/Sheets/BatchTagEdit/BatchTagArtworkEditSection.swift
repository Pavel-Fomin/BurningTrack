//
//  BatchTagArtworkEditSection.swift
//  TrackList
//
//  UI-секция редактирования обложек при массовом редактировании тегов.
//
//  Created by PavelFomin on 25.05.2026.
//

import SwiftUI

/// UI-секция редактирования обложек при массовом редактировании тегов.
struct BatchTagArtworkEditSection: View {
    /// Состояние редактирования обложек.
    @Binding var artwork: BatchTagArtworkEditState
    /// Обработчик действия из меню карточки.
    let onMenuAction: (BatchTagArtworkMenuAction, BatchTagArtworkActionTarget) -> Void
    var body: some View {
        previewScroll
    }
    /// Горизонтальный список preview-карточек.
    private var previewScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                BatchTagArtworkSummaryCard(
                    summary: artwork.previewSummary,
                    isSelected: artwork.selectedTarget == .summary,
                    onSelect: {
                        artwork.selectedTarget = .summary
                    },
                    onMenuAction: onMenuAction
                )
                ForEach(artwork.previewItems) { item in
                    let hasArtworkForPreview = hasArtworkForPreview(for: item)
                    BatchTagArtworkPreviewCard(
                        item: item,
                        hasArtworkForPreview: hasArtworkForPreview,
                        isSelected: artwork.selectedTarget == .track(item.trackId),
                        onSelect: {
                            artwork.selectedTarget = .track(item.trackId)
                        },
                        onMenuAction: onMenuAction
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// Определяет, должна ли карточка визуально показывать обложку с учётом несохранённых изменений.
    private func hasArtworkForPreview(for item: BatchTagArtworkPreviewItem) -> Bool {
        switch artwork.action(for: item.trackId) {
        case .keep:
            return item.hasArtwork
        case .remove:
            return false
        case .replace:
            return item.hasArtwork
        }
    }
}
