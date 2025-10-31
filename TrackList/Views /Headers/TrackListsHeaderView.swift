//
//  TrackListsHeaderView.swift
//  TrackList
//
//  Хедер "Треклисты"
//
//  Created by Pavel Fomin on 16.05.2025.
//

import SwiftUI

struct TrackListHeaderView: View {
    var isEditing: Bool
    var onAdd: () -> Void
    var onEditToggle: () -> Void

    var body: some View {
        ScreenHeaderView(title: "Треклисты") {
            EmptyView()
        } trailing: {
            Menu {
                Button("Новый треклист", action: {})
                Button("Удалить несколько", action: {})
            } label: {
                Image(systemName: "ellipsis.circle")
                    .headerIconStyle()
            }
        }
    }
}
