//
//  TrackDetailReadOnlyView.swift
//  TrackList
//
//  Read-only представление информации о треке.
//
//  Роль:
//  - отображает путь, технические данные, имя файла и теги
//  - полностью повторяет текущий UI просмотра
//  - не содержит логики редактирования
//
//  Архитектура:
//  - получает все данные через параметры
//  - не хранит состояние
//  - не знает о режимах (view/edit)
//
//  Created by Pavel Fomin on 27.01.2026.
//

import SwiftUI

struct TrackDetailReadOnlyView: View {
    
    // MARK: - Data
    
    let artworkUIImage: UIImage?
    let filePath: String?
    let fileTechnicalInfo: String
    let fileName: String?
    let tags: [(field: EditableTrackField, value: String)]
    
    // MARK: - UI
    
    var body: some View {
        List {
            
            // Artwork (HEADER, не row)
            Section {
                EmptyView()
            } header: {
                artworkHeader
            }
            
            // SECTION 2 — Metadata
            Section {
                
                ListRow(
                    title: TrackDetailPresentationText.filePathTitle,
                    value: filePath ?? TrackDetailPresentationText.unavailableTechnicalValue,
                    isMonospaced: true,
                    isSecondary: true
                )

                ListRow(
                    title: TrackDetailPresentationText.aboutFileTitle,
                    value: fileTechnicalInfo
                )
                
                ListRow(
                    title: TagEditorPresentationText.fileNameTitle,
                    value: fileName ?? TrackDetailPresentationText.unavailableTechnicalValue
                )
                
                ForEach(tags, id: \.field) { item in
                    ListRow(
                        title: TagEditorPresentationText.fieldTitle(for: item.field),
                        value: item.value.isEmpty
                            ? TrackDetailPresentationText.missingMetadataValue
                            : item.value
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Artwork header
    
    private var artworkHeader: some View {
        VStack {
            if let artworkUIImage {
                Image(uiImage: artworkUIImage)
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
                hasArtwork: artworkUIImage != nil
            )
        )
    }
    
    // MARK: - ListRow
    
    private struct ListRow: View {
        
        let title: String
        let value: String
        var isMonospaced: Bool = false
        var isSecondary: Bool = false
        
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                
                Text(title.uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.body)
                    .foregroundColor(isSecondary ? .secondary : .primary)
                    .lineLimit(4)
                    .textSelection(.enabled)
                    .monospaced(isMonospaced)
            }
            .padding(.vertical, 4)
        }
    }
}
