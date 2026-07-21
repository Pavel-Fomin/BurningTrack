//
//  BatchTagArtworkCardMenu.swift
//  TrackList
//
//  Единое меню действий для карточек обложек.
//
//  Created by Pavel Fomin on 25.05.2026.
//

import SwiftUI

/// Единое меню действий для карточек обложек.
struct BatchTagArtworkCardMenu: View {
    /// Обработчик выбранного действия.
    let onAction: (BatchTagArtworkMenuAction) -> Void

    var body: some View {
        Menu {
            Button(String(localized: "Delete")) {
                onAction(.remove)
            }
            Button(String(localized: "Replace")) {
                onAction(.replace)
            }
            Menu(BatchTagEditPresentationText.compressArtworkTitle) {
                ForEach(BatchArtworkCompressionOption.allCases, id: \.self) { option in
                    Button(
                        BatchTagEditPresentationText.compressionOptionTitle(for: option)
                    ) {
                        onAction(.compress(option))
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body)
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .accessibilityLabel(BatchTagEditPresentationText.artworkActionsAccessibilityLabel)
    }
}
