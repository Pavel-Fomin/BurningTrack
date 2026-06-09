//
//  BatchTagArtworkPreviewCard.swift
//  TrackList
//
//  Карточка preview одной обложки в форме массового редактирования тегов.
//
//  Created by Pavel Fomin on 25.05.2026.
//

import SwiftUI
import UIKit

/// Карточка preview одной обложки в форме массового редактирования тегов.
struct BatchTagArtworkPreviewCard: View {
    /// Загруженное preview-изображение обложки.
    @State private var image: UIImage?
    /// Preview-элемент обложки.
    let item: BatchTagArtworkPreviewItem
    /// Должна ли карточка показывать обложку с учётом несохранённых изменений.
    let hasArtworkForPreview: Bool
    /// Выбрана ли карточка.
    let isSelected: Bool
    /// Обработчик выбора карточки.
    let onSelect: () -> Void
    /// Обработчик действия из меню.
    let onMenuAction: (BatchTagArtworkMenuAction, BatchTagArtworkActionTarget) -> Void
    var body: some View {
        artworkView
            .onTapGesture {
                onSelect()
            }
            .batchTagArtworkSelection(isSelected)
            .task(id: "\(item.trackId.uuidString)-\(hasArtworkForPreview)") {
                await loadArtworkIfNeeded()
            }
            .onDisappear {
                image = nil
            }
    }
    /// Обложка или placeholder.
    @ViewBuilder
    private var artworkView: some View {
        ZStack(alignment: .topTrailing) {
            artworkContent
            menuButton
                .padding(8)
        }
    }
    /// Основное содержимое обложки.
    @ViewBuilder
    private var artworkContent: some View {
        if hasArtworkForPreview, let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 150, height: 150)
                .clipShape(previewShape)
        } else {
            placeholder
        }
    }
    /// Placeholder при отсутствии обложки.
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
    /// Кнопка меню действий.
    private var menuButton: some View {
        BatchTagArtworkCardMenu {
            onMenuAction($0, .track(item.trackId))
        }
    }

    /// Фиксированный размер preview обложки.
    private var previewShape: some Shape {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }

    /// Лениво загружает preview-изображение обложки.
    private func loadArtworkIfNeeded() async {
        image = nil
        guard hasArtworkForPreview else { return }
        let loadedImage = await BatchTagArtworkPreviewLoader.shared.image(
            forTrackId: item.trackId,
            hasArtwork: hasArtworkForPreview
        )
        guard !Task.isCancelled else { return }
        image = loadedImage
    }
}
