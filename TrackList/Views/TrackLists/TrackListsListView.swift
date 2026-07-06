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
                ForEach(state.rows) { row in
                    trackListRow(for: row)
                }
                .onMove { source, destination in
                    onAction(.moveTrackList(source, destination))
                }
            }
            .onAppear {
                onAction(.onAppear)
            }
            .listStyle(.insetGrouped)
        }
        .alert(
            "Удалить треклист?",
            isPresented: Binding(
                get: { state.isShowingDeleteConfirmation },
                set: { isPresented in
                    if !isPresented {
                        onAction(.cancelDeleteTrackList)
                    }
                }
            )
        ) {
            Button("Удалить", role: .destructive) {
                if let id = state.pendingDeleteTrackListId {
                    onAction(.confirmDeleteTrackList(id))
                }
            }
            Button("Отмена", role: .cancel) {
                onAction(.cancelDeleteTrackList)
            }
        } message: {
            Text("Треклист удалится безвозвратно")
        }
    }
    
    @ViewBuilder
    private func trackListRow(for row: TrackListsRowState) -> some View {
        Button {
            onAction(.openTrackList(row.id))
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title)
                        .font(.body)
                        .fontWeight(.regular)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(row.createdAtText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()

                Text(row.tracksCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onAction(.requestDeleteTrackList(row.id))
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }
}
