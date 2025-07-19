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
            HStack(spacing: 12) {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                }

                Button(action: onEditToggle) {
                    if isEditing {
                        Text("Готово")
                            .font(.system(size: 14, weight: .semibold))
                    } else {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
        }
    }
}
