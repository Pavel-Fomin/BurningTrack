//
//  TrackListHeaderView.swift
//  TrackList
//
//  Компонент хедера раздела "Треклист".
//  Содержит тулбар с кнопками и строку выбора треклистов (чипсы)
//
//  Created by Pavel Fomin on 16.05.2025.
//

import SwiftUI

struct TrackListHeaderView: View {
    @ObservedObject var viewModel: TrackListViewModel
    @Binding var selectedId: UUID?
    
    let onSelect: (UUID) -> Void
    let onAddFromPlus: () -> Void
    let onAddFromContextMenu: () -> Void
    let onToggleEditMode: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Верхний тулбар с заголовком и кнопками "+" / "Изменить"
            TrackListToolbar(
                isEditing: viewModel.isEditing,
                hasTrackLists: !viewModel.trackLists.isEmpty,
                onAdd: onAddFromPlus,
                onToggleEditMode: onToggleEditMode
            )
            
            // Строка чипсов с треклистами
            TrackListSelectorView(
                viewModel: viewModel,
                selectedId: Binding<UUID>(
                    get: {
                        selectedId ?? UUID() // если selectedId == nil, создаём временный ID
                    },
                    set: {
                        selectedId = $0
                    }
                ),
                onSelect: onSelect,
                onAddFromPlus: onAddFromPlus,
                onAddFromContextMenu: onAddFromContextMenu,
                onToggleEditMode: onToggleEditMode
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .background(Colors.customHeaderBackground)
    }
}
