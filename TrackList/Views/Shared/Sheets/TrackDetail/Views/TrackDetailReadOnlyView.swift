//
//  TrackDetailReadOnlyView.swift
//  TrackList
//
//  Read-only отображение готовой информации Track Detail.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import SwiftUI

/// Leaf View без runtime, storage и навигационных зависимостей.
struct TrackDetailReadOnlyView: View {
    /// Готовое presentation state для вывода данных.
    let state: TrackDetailScreenState

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
    }

    /// Показывает artwork через существующий presentation-only preparation component.
    private var artworkHeader: some View {
        ArtworkPreparationView(request: state.artwork.request) { image in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 48)
        } placeholder: {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 180, height: 180)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                )
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
