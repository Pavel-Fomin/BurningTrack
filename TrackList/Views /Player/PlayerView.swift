//
// PlayerView.swift
// TrackList
//
// Экран плеера со списком треков
//
// Created by Pavel Fomin on 14.07.2025.
//

import Foundation
import SwiftUI

struct PlayerView: View {
    let tracks: [Track]               // Список треков
    let currentTrack: Track?          // Текущий трек
    let isPlaying: Bool               // Играет сейчас
    let onTrackTap: (Track) -> Void   // Действие при тапе
    
    var body: some View {
        List {
            ForEach(tracks) { track in
                let leftSwipe: [CustomSwipeAction] = [
                    CustomSwipeAction(
                        label: "Удалить",
                        systemImage: "trash",
                        role: .destructive,
                        tint: .red,
                        handler: {
                            if let index = tracks.firstIndex(where: { $0.id == track.id }) {
                                PlaylistManager.shared.tracks.remove(at: index)
                                PlaylistManager.shared.saveToDisk()
                            }
                        },
                        labelType: .iconOnly
                    )
                ]
                TrackRowView(
                    track: track,
                    isCurrent: track.id == currentTrack?.id,
                    isPlaying: track.id == currentTrack?.id && isPlaying,
                    onTap: {
                        onTrackTap(track)
                    },
                    swipeActionsLeft: leftSwipe,
                    swipeActionsRight: []
                )
                
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        
    }
}
