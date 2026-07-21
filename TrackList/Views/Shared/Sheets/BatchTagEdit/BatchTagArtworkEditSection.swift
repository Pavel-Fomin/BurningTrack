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
        VStack(alignment: .leading, spacing: 8) {
            previewScroll
            if artwork.compressionFailureCount > 0 {
                Text(compressionFailureText)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
            }
        }
    }

    /// Текст ошибки сжатия обложек.
    private var compressionFailureText: String {
        BatchTagEditPresentationText.compressionFailureText(
            for: artwork.compressionFailureCount
        )
    }

    /// Горизонтальный список preview-карточек.
    private var previewScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                BatchTagArtworkSummaryCard(
                    summary: artwork.previewSummary,
                    totalArtworkSizeBytesForPreview: totalArtworkSizeBytesForPreview,
                    isSelected: artwork.selectedTarget == .summary,
                    onSelect: {
                        artwork.selectedTarget = .summary
                    },
                    onMenuAction: onMenuAction
                )
                ForEach(artwork.previewItems) { item in
                    let hasArtworkForPreview = hasArtworkForPreview(for: item)
                    let artworkAction = artwork.action(for: item.trackId)
                    let artworkSizeBytesForPreview = artworkSizeBytesForPreview(for: item)
                    BatchTagArtworkPreviewCard(
                        item: item,
                        artworkAction: artworkAction,
                        hasArtworkForPreview: hasArtworkForPreview,
                        artworkSizeBytesForPreview: artworkSizeBytesForPreview,
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

    /// Возвращает размер обложки с учётом несохранённых изменений.
    private func artworkSizeBytesForPreview(for item: BatchTagArtworkPreviewItem) -> Int {
        switch artwork.action(for: item.trackId) {
        case .keep:
            return item.artworkSizeBytes ?? 0
        case .remove:
            return 0
        case .replace(let data):
            return data.count
        }
    }

    /// Возвращает общий размер обложек с учётом несохранённых изменений.
    private var totalArtworkSizeBytesForPreview: Int {
        artwork.previewItems.reduce(0) { result, item in
            result + artworkSizeBytesForPreview(for: item)
        }
    }
}
