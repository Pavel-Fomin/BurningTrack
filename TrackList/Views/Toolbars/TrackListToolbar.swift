//
//  TrackListToolbar.swift
//  TrackList
//
//  Тулбар для отдельного треклиста
//
//  Created by Pavel Fomin on 09.11.2025.
//

import SwiftUI

struct TrackListToolbar: ViewModifier {

    let title: String
    let onAction: (TrackListAction) -> Void

    // MARK: - UI
    
    func body(content: Content) -> some View {
        content
            .screenToolbar(
                title: title,
                leading: { EmptyView() }
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Добавить трек") {
                            onAction(.addTrack)
                        }
                        Button("Экспорт") {
                            onAction(.export)
                        }
                        Button("Переименовать") {
                            onAction(.renameTrackList)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
    }
}

// MARK: - Modifier

extension View {

    func trackListToolbar(
        title: String,
        onAction: @escaping (TrackListAction) -> Void
    ) -> some View {
        self.modifier(
            TrackListToolbar(
                title: title,
                onAction: onAction
            )
        )
    }
}
