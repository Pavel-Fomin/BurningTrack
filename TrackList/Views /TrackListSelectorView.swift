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
                if viewModel.isEditingTrackLists {
                    // Кнопка "Готово" слева
                    doneButton
                }

                // Кнопка "Изменить" внутри скролла, будет вытеснена
                if !viewModel.isEditingTrackLists {
                    editButton
                }

                // Spacer, который толкает кнопку "Изменить" вправо
                if !viewModel.isEditingTrackLists {

                }

                // Кнопка "+"
                if !viewModel.isEditingTrackLists {
                    addButton
                }

                // Чипсы
                ForEach(viewModel.allTrackLists, id: \.id) { list in
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
                        isEditing: viewModel.isEditingTrackLists && list.id != selectedId,
                        onEdit: {
                            viewModel.isEditingTrackLists = true
                        }
                    )
                }
            }
            .padding(.leading, 0)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Кнопка "+"
    private var addButton: some View {
        Button(action: {
            print("🟢 Кнопка '+' нажата")
            onAddFromPlus()
        }) {
            Image(systemName: "plus")
                .resizable()
                .frame(width: 16, height: 16)
                .padding(8)
                .background(Circle().fill(Color.gray.opacity(0.3)))
                .foregroundColor(.primary)
        }
    }

    // MARK: - Кнопка "Редактировать"
    private var editButton: some View {
        Button(action: {
            withAnimation {
                viewModel.isEditingTrackLists = true
            }
        }) {
            Image(systemName: "wand.and.sparkles.inverse")
                .font(.system(size: 20))
                .foregroundColor(.primary)
        }
    }

    // MARK: - Кнопка "Готово"
    private var doneButton: some View {
        Button(action: {
            withAnimation {
                viewModel.isEditingTrackLists = false
            }
        }) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(.accentColor)
        }
    }
}
