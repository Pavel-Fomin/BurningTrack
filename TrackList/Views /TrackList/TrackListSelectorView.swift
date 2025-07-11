//
//  TrackListSelectorView.swift
//  TrackList
//
//  Компонент выбора треклиста (горизонтальный список чипов).
//  Содержит логику отображения, удаления, очистки и переименования.
//
//  Created by Pavel Fomin on 08.05.2025.
//

import Foundation
import SwiftUI
import UIKit

struct TrackListSelectorView: View {
    @ObservedObject var viewModel: TrackListViewModel
    @Binding var selectedId: UUID
    
    var onSelect: (UUID) -> Void
    var onAddFromPlus: () -> Void
    var onAddFromContextMenu: () -> Void
    let onToggleEditMode: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                
                TrackListChipsGroupView(
                    trackLists: viewModel.trackLists,
                    selectedId: selectedId,
                    isEditing: viewModel.isEditing,
                    
                    // Выбор чипа
                    onSelect: { id in
                        selectedId = id
                        onSelect(id)
                    },
                    
                    // Добавление трека из контекстного меню
                    onAddFromContextMenu: onAddFromContextMenu,
                    
                    // Удаление чипа (если можно)
                    onDelete: { id in
                        if viewModel.canDeleteTrackList(id: id) {
                            viewModel.deleteTrackList(id: id)
                        } else {
                            print("Нельзя удалить: треклист не пуст")
                        }
                    },
                    
                    // Завершение режима редактирования
                    onDoneEditing: {
                        viewModel.isEditing = false
                    },
                    
                    // Переименование — обновляем список
                    onRename: {
                        viewModel.refreshTrackLists()
                    }
                )
                .padding(.leading, 0)
                .padding(.bottom, 12)
                .onReceive(NotificationCenter.default.publisher(for: .clearTrackList)) { notification in
                    if let id = notification.object as? UUID {
                        viewModel.clearTrackList(id: id)
                    }
                }
            }
        }
    }
}
