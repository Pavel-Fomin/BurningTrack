//
//  TrackDetailReadOnlyView.swift
//  TrackList
//
//  Read-only отображение готовой информации Track Detail.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import SwiftUI
import UIKit

/// Leaf View без runtime, storage и навигационных зависимостей.
struct TrackDetailReadOnlyView: View {
    /// Готовое presentation state для вывода данных.
    let state: TrackDetailScreenState
    /// Узкая capability подготовки обложек приходит из Composition Root.
    @Environment(\.artworkImageProvider) private var artworkImageProvider
    /// Результат живёт выше List-header, который SwiftUI может materialize повторно.
    @State private var artworkImage: UIImage?

    var body: some View {
        List {
            Section {
                EmptyView()
            } header: {
                artworkHeader
            }

            Section {
                TrackDetailValueRow(
                    title: TrackDetailPresentationText.filePathTitle,
                    value: state.filePath
                        ?? TrackDetailPresentationText.unavailableTechnicalValue,
                    isMonospaced: true,
                    isSecondary: true
                )

                TrackDetailValueRow(
                    title: TrackDetailPresentationText.aboutFileTitle,
                    value: state.technicalInfo
                )

                TrackDetailValueRow(
                    title: TagEditorPresentationText.fileNameTitle,
                    value: state.fileName
                )

                ForEach(EditableTrackField.allCases, id: \.self) { field in
                    TrackDetailValueRow(
                        title: TagEditorPresentationText.fieldTitle(for: field),
                        value: state.editableValues[field] ?? ""
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        // Разрешает header отрисовать тень за границами scroll-контейнера.
        .scrollClipDisabled()
        .task(id: state.artwork.request?.loadIdentifier) {
            artworkImage = nil
            guard let request = state.artwork.request else { return }

            let preparedImage = await ArtworkImageLoader(
                provider: artworkImageProvider
            ).image(for: request)
            guard !Task.isCancelled else { return }
            artworkImage = preparedImage
        }
    }

    /// Показывает artwork из устойчивого состояния родительского View, не создавая новый lifecycle header.
    private var artworkHeader: some View {
        Group {
            if let artworkImage {
                Image(uiImage: artworkImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 180, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 48)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 180, height: 180)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.clear)
        .accessibilityLabel(
            TagEditorPresentationText.artworkAccessibilityLabel(
                hasArtwork: state.artwork.request != nil
            )
        )
    }
}

/// Повторяет локальную геометрию строк Track Detail без domain-зависимостей.
private struct TrackDetailValueRow: View {
    /// Подпись свойства.
    let title: String
    /// Готовое значение свойства.
    let value: String
    /// Нужно ли применить моноширинное начертание.
    var isMonospaced = false
    /// Нужно ли показать значение вторичным цветом.
    var isSecondary = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundColor(.secondary)

            Text(
                value.isEmpty
                    ? TrackDetailPresentationText.missingMetadataValue
                    : value
            )
            .font(.body)
            .foregroundColor(isSecondary ? .secondary : .primary)
            .lineLimit(4)
            .textSelection(.enabled)
            .monospaced(isMonospaced)
        }
        .padding(.vertical, 4)
    }
}
