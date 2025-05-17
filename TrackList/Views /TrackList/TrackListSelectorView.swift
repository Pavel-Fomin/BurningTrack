//
//  TrackListSelectorView.swift
//  TrackList
//
//  Компонент выбора треклиста(группа чип-вью)
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
                if viewModel.isEditing {
                    // Кнопка "Готово" слева
                    doneButton
                }

                // Чипсы
                ForEach(viewModel.trackLists, id: \.id) { list in
                    TrackListChipView(
                        trackList: list,
                        isSelected: list.id == selectedId,
                        onSelect: {
                            selectedId = list.id
                            onSelect(list.id)
                        },
                        onAdd: {
                            if list.id == selectedId {
                                onAddFromContextMenu()
                            }
                        },
                        onDelete: {
                            if list.id != selectedId {
                                viewModel.deleteTrackList(id: list.id)
                            }
                        },
                        isEditing: viewModel.isEditing && list.id != selectedId,
                        onEdit: {
                            viewModel.isEditing = true
                        }
                    )
                }
            }
            .padding(.leading, 0)
            .padding(.bottom, 12)
        }
    }

    
    // MARK: - Кнопка "Готово"
    private var doneButton: some View {
        Button(action: {
            withAnimation {
                viewModel.isEditing = false
            }
        }) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(.accentColor)
        }
    }
}
