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
    let tracks: [PlayerTrack]
    @ObservedObject var playerViewModel: PlayerViewModel

    var body: some View {
        List {
            PlayerRowsView(
                tracks: tracks,
                playerViewModel: playerViewModel
            )
        }
        .safeAreaInset(edge: .bottom) {Color.clear.frame(height: 88)}
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        
    }

    // MARK: - Компонент строк плеера
    
    private struct PlayerRowsView: View {
        let tracks: [any TrackDisplayable]
        let playerViewModel: PlayerViewModel

        var body: some View {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { _, track in
                let isCurrent = playerViewModel.isCurrent(track, in: .player)
                let isPlaying = isCurrent && playerViewModel.isPlaying

                PlayerTrackRowWrapper(
                    track: track,
                    isCurrent: isCurrent,
                    isPlaying: isPlaying,
                    onTap: {
                        if isCurrent {
                            playerViewModel.togglePlayPause()
                        } else {
                            playerViewModel.play(track: track, context: tracks)
                        }
                    },
                        playerViewModel: playerViewModel
                )
            }
            .onMove { from, to in
                PlaylistManager.shared.tracks.move(fromOffsets: from, toOffset: to)
                PlaylistManager.shared.saveToDisk()
            }
        }
    }
}
