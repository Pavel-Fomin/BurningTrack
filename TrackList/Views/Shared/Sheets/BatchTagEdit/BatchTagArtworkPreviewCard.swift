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
    /// Несохранённое действие с обложкой для этой карточки.
    let artworkAction: BatchTagArtworkEditAction
    /// Должна ли карточка показывать обложку с учётом несохранённых изменений.
    let hasArtworkForPreview: Bool
    /// Размер preview-обложки в байтах с учётом несохранённых изменений.
    let artworkSizeBytesForPreview: Int
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                BatchTagEditPresentationText.artworkPreviewAccessibilityLabel(
                    title: item.title,
                    hasArtwork: hasArtworkForAccessibility
                )
            )
            .accessibilityValue(
                isSelected ? String(localized: "Selected") : ""
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                onSelect()
            }
            .task(id: previewTaskId) {
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
            VStack {
                Spacer()
                sizeBadge
                    .padding(.bottom, 8)
            }
            .frame(width: 150, height: 150)
            menuButton
                .padding(8)
        }
    }
    /// Основное содержимое обложки.
    @ViewBuilder
    private var artworkContent: some View {
        switch artworkAction {
        case .replace(let data):
            if let replacementImage = UIImage(data: data) {
                Image(uiImage: replacementImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 150, height: 150)
                    .clipShape(previewShape)
            } else {
                placeholder
            }
        case .keep, .remove:
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
    }

    /// Идентификатор перезагрузки preview при изменении локального состояния обложки.
    private var previewTaskId: String {
        switch artworkAction {
        case .keep:
            return "\(item.trackId.uuidString)-keep-\(hasArtworkForPreview)"
        case .remove:
            return "\(item.trackId.uuidString)-remove-\(hasArtworkForPreview)"
        case .replace(let data):
            return "\(item.trackId.uuidString)-replace-\(data.count)"
        }
    }

    /// Форматированный размер preview-обложки.
    private var formattedArtworkSize: String {
        BatchTagArtworkSizeFormatter.string(from: artworkSizeBytesForPreview)
    }

    /// Учитывает несохранённую замену или удаление при формировании VoiceOver-подписи.
    private var hasArtworkForAccessibility: Bool {
        switch artworkAction {
        case .keep:
            return hasArtworkForPreview
        case .remove:
            return false
        case .replace:
            return true
        }
    }

    /// Подпись с размером обложки внутри карточки.
    private var sizeBadge: some View {
        Text(formattedArtworkSize)
            .font(.caption2)
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.55))
            .clipShape(Capsule())
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
        if case .replace = artworkAction {
            return
        }
        guard hasArtworkForPreview else { return }
        let loadedImage = await BatchTagArtworkPreviewLoader.shared.image(
            forTrackId: item.trackId,
            hasArtwork: hasArtworkForPreview
        )
        guard !Task.isCancelled else { return }
        image = loadedImage
    }
}
