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
            Button("Удалить") {
                onAction(.remove)
            }
            Button("Заменить") {
                onAction(.replace)
            }
            Button("Сжать") {
                onAction(.compress)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body)
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
    }
}
