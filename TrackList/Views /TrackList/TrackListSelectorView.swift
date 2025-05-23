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
                
                TrackListChipsGroupView( /// Чипсы
                    trackLists: viewModel.trackLists,
                        selectedId: selectedId,
                        isEditing: viewModel.isEditing,
                        onSelect: { id in
                            selectedId = id
                            onSelect(id)
                        },
                        onAddFromContextMenu: onAddFromContextMenu,
                    onDelete: { id in
                        if id == selectedId {
                            // выбранный треклист — удаляем ТОЛЬКО если он пустой
                            let tracks = TrackListManager.shared.loadTracks(for: id)
                            if tracks.isEmpty {
                                viewModel.deleteTrackList(id: id)
                            } else {
                                print("⚠️ Нельзя удалить: треклист не пуст")
                            }
                        } else {
                            // невыбранный треклист — удаляем всегда
                            viewModel.deleteTrackList(id: id)
                        }
                        
                        },
                        onDoneEditing: {
                            viewModel.isEditing = false
                        },
                        onRename: {
                            viewModel.refreshtrackLists()
                        }
                    )
                    .padding(.leading, 0)
                    .padding(.bottom, 12)
                    }
            }
        }
        
    }
