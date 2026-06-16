//
//  TrackListsToolbar.swift
//  TrackList
//
//  Тулбар для раздела “Треклисты”
//
//  Created by Pavel Fomin on 09.11.2025.
//

import SwiftUI

struct TrackListsToolbar: ViewModifier {
    /// Запрашивает создание нового треклиста.
    let onCreateTrackList: () -> Void

    // MARK: - UI

    func body(content: Content) -> some View {
        content
            .screenToolbar(
                title: "Треклисты",
                leading: { EmptyView() },
                trailing: {
                    Menu {
                        Button {
                            onCreateTrackList()
                        } label: {
                            Label("Новый треклист", systemImage: "plus")
                    
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            )
    }
}

// MARK: - Modifier
extension View {
    
    func trackListsToolbar(
        onCreateTrackList: @escaping () -> Void
    ) -> some View {
        self.modifier(
            TrackListsToolbar(
                onCreateTrackList: onCreateTrackList
            )
        )
    }
}
