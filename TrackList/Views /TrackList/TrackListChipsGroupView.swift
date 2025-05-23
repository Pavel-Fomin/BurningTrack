//
//  TrackListChipsGroupView.swift
//  TrackList
//
//  Группа чип-вью
//
//  Created by Pavel Fomin on 21.05.2025.
//

import SwiftUI

struct TrackListChipsGroupView: View {
    let trackLists: [TrackList]
    let selectedId: UUID
    let isEditing: Bool
    let onSelect: (UUID) -> Void
    let onAddFromContextMenu: () -> Void
    let onDelete: (UUID) -> Void
    let onDoneEditing: () -> Void
    let onRename: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            editingButtonIfNeeded /// кнопка "Готово"
            chipsList             /// чипсы
        }
        .animation(.chipEditMode, value: isEditing)
    }

    private var editingButtonIfNeeded: some View {
        Group {
            if isEditing {
                Button(action: {
                    withAnimation(.chipEditMode) {
                        onDoneEditing()
                    }
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                }
            }
        }
    }

    @ViewBuilder
    var chipsList: some View {
        ForEach(trackLists) { trackList in
            animatedChipView(for: trackList)
        }
    }

    @ViewBuilder
    private func animatedChipView(for trackList: TrackList) -> some View {
        TrackListChipView(
            trackList: trackList,
            isSelected: trackList.id == selectedId,
            isEditing: isEditing, onSelect: { onSelect(trackList.id) },
            onAdd: onAddFromContextMenu,
            onDelete: { onDelete(trackList.id) },
            onEdit: onRename
        )
        .id(trackList.id)
    }
}
