//
//  TrackSelectableRowWrapper.swift
//  TrackList
//
//  Обёртка для использования TrackRowView в режиме выбора треков.
//  Не содержит логики плеера и сторонних зависимостей.
//
//  Created by Pavel Fomin on 30.04.2026.
//

import SwiftUI

struct TrackSelectableRowWrapper: View {
    
    // MARK: - Input
    
    let state: TrackSelectableRowState
    let onToggleSelection: () -> Void
    let onRequestSnapshot: (UUID) -> Void
    
    // MARK: - UI
    
    var body: some View {
        TrackRowView(
            track: state.track,
            isCurrent: false,
            isPlaying: false,
            isHighlighted: false,
            artworkRequest: state.artworkRequest,
            artworkBadgeState: state.artworkBadgeState,
            title: state.title,
            artist: state.artist,
            duration: state.duration,
            onRowTap: {
                onToggleSelection()
            },
            showsSelection: true,
            isSelected: state.isSelected,
            onToggleSelection: onToggleSelection,
            selectionPlacement: .trailing,
            showsFileFormat: state.showsFileFormat
        )
        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
        .task(id: state.track.trackId) {
            onRequestSnapshot(state.track.trackId)
        }
    }
}
