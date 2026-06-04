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
                    BatchTagArtworkPreviewCard(
                        item: item,
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
}
