//
//  TrackListHeaderView.swift
//  TrackList
//
//  Хедер раздела "Tracklist"
//
//  Created by Pavel Fomin on 16.05.2025.
//

import SwiftUI

struct TrackListHeaderView: View {
    @ObservedObject var viewModel: TrackListViewModel
    @Binding var selectedId: UUID
    
    let onSelect: (UUID) -> Void
    let onAddFromPlus: () -> Void
    let onAddFromContextMenu: () -> Void
    let onToggleEditMode: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TrackListToolbar(
                isEditing: viewModel.isEditing,
                onAdd: onAddFromPlus,
                onToggleEditMode: onToggleEditMode
            )
            
            TrackListSelectorView(
                viewModel: viewModel,
                selectedId: $selectedId,
                onSelect: onSelect,
                onAddFromPlus: onAddFromPlus,
                onAddFromContextMenu: onAddFromContextMenu
            )
            
        }
    }
}
