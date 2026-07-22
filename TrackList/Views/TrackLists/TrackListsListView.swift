//
//  TrackListsListView.swift
//  TrackList
//
//  Cписок треклистов
//
//  Created by Pavel Fomin on 18.07.2025.
//

import Foundation
import SwiftUI

struct TrackListsListView: View {
    /// Готовое состояние экрана списка треклистов.
    let state: TrackListsScreenState
    /// Передаёт пользовательские действия обработчику экрана.
    let onAction: (TrackListsAction) -> Void
    
    var body: some View {
        ZStack {
            List {
                if state.rows.isEmpty {
                    ContentUnavailableView(
                        "No Tracklists",
                        systemImage: "music.note.list"
                    )
                } else {
                    ForEach(state.rows) { row in
                        trackListRow(for: row)
                    }
                    .onMove { source, destination in
                        onAction(.moveTrackList(source, destination))
                    }
                }
            }
            .onAppear {
                onAction(.onAppear)
            }
            .listStyle(.insetGrouped)
            .globalBottomScrollReserve()
        }
        .alert(
            "Delete Tracklist?",
            isPresented: Binding(
                get: { state.isShowingDeleteConfirmation },
                set: { isPresented in
                    if !isPresented {
                        onAction(.cancelDeleteTrackList)
                    }
                }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let id = state.pendingDeleteTrackListId {
                    onAction(.confirmDeleteTrackList(id))
                }
            }
            Button("Cancel", role: .cancel) {
                onAction(.cancelDeleteTrackList)
            }
        } message: {
            Text("This tracklist will be permanently deleted.")
        }
    }
    
    @ViewBuilder
    private func trackListRow(for row: TrackListsRowState) -> some View {
        TrackListsRowView(row: row) {
            onAction(.openTrackList(row.id))
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onAction(.requestDeleteTrackList(row.id))
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
