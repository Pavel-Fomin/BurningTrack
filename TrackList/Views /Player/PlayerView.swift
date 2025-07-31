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
    
    @ObservedObject var artworkProvider: ArtworkProvider
    
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
                            if let index = PlaylistManager.shared.tracks.firstIndex(where: { $0.id == track.id }) {
                                PlaylistManager.shared.remove(at: index)
                            }
                        },
                        labelType: .iconOnly
                    )
                ]
                
                TrackRowView(
                    track: track,
                    isCurrent: track.id == currentTrack?.id,
                    isPlaying: track.id == currentTrack?.id && isPlaying,
                    artwork: artworkProvider.artwork(for: track.url),
                    onTap: {
                        onTrackTap(track)
                    },
                    swipeActionsLeft: leftSwipe,
                    swipeActionsRight: [],
                    trackListNames: [],
                    useNativeSwipeActions: false
                )
                .onAppear {
                    artworkProvider.loadArtworkIfNeeded(for: track.url)
                }
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
