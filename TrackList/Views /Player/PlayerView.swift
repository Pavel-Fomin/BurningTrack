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
                TrackRowView(
                    track: track,
                    isCurrent: track.id == currentTrack?.id,
                    isPlaying: track.id == currentTrack?.id && isPlaying,
                    onTap: {
                        onTrackTap(track)
                    },
                        onSwipeLeft: {
                            if let index = tracks.firstIndex(where: { $0.id == track.id }) {
                                PlaylistManager.shared.tracks.remove(at: index)
                                PlaylistManager.shared.saveToDisk()
                            }
                        }
                    )
                
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .background(
                    track.id == currentTrack?.id ? Color.gray.opacity(0.1) : Color.clear
                )
            }
        }
        .listStyle(.plain)
        .navigationTitle("Плейлист")
    }
}
