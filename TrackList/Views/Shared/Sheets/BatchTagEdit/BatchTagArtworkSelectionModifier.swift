//
//  BatchTagArtworkSelectionModifier.swift
//  TrackList
//
//  Modifier обводки выбранной карточки обложки.
//
//  Created by Pavel Fomin on 25.05.2026.
//

import SwiftUI

/// Modifier обводки выбранной карточки обложки.
struct BatchTagArtworkSelectionModifier: ViewModifier {
    /// Выбрана ли карточка.
    let isSelected: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
            }
        }
    }
}

extension View {
    /// Добавляет обводку выбранной карточки обложки.
    func batchTagArtworkSelection(_ isSelected: Bool) -> some View {
        modifier(BatchTagArtworkSelectionModifier(isSelected: isSelected))
    }
}
