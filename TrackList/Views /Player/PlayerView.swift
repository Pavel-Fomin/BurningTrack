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
    let tracks: [Track]                 // Список треков
    let currentTrack: Track?            // Текущий трек
    let isPlaying: Bool                 // Играет сейчас
    let onTrackTap: (Track) -> Void     // Действие при тапе
    
    @State private var artwork: UIImage? = nil
    
    var body: some View {
        List {
            ForEach(tracks) { track in
                PlayerTrackRowView(
                    track: track,
                    isCurrent: track.id == currentTrack?.id,
                    isPlaying: track.id == currentTrack?.id && isPlaying,
                    onTap: { onTrackTap(track) }
                )
            }
            .onMove { from, to in
                PlaylistManager.shared.tracks.move(fromOffsets: from, toOffset: to)
                PlaylistManager.shared.saveToDisk()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
