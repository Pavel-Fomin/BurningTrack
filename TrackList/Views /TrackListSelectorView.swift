//
//  TrackListSelectorView.swift
//  TrackList
//
//  Компонент выбора треклиста
//
//  Created by Pavel Fomin on 08.05.2025.
//

import Foundation
import SwiftUI

struct TrackListSelectorView: View {
    @ObservedObject var viewModel: TrackListViewModel
    @Binding var selectedId: UUID
    var onSelect: (UUID) -> Void
    var onAddFromPlus: () -> Void
    var onAddFromContextMenu: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                addButton
                ForEach(viewModel.allTrackLists, id: \.id) { list in
                    TrackListChipView(
                        trackList: list,
                        isSelected: list.id == selectedId,
                        onSelect: {
                            selectedId = list.id
                            onSelect(list.id)
                        },
                        onAdd: onAddFromContextMenu
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
    }

    private var addButton: some View {
        Button(action: {
            print("🟢 Кнопка '+' нажата")
            onAddFromPlus()
        }) {
            Image(systemName: "plus")
                .padding(8)
                .background(Circle().fill(Color.gray.opacity(0.3)))
                .foregroundColor(.primary)
        }
    }
}
