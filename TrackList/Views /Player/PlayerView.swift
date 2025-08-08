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
    let tracks: [any TrackDisplayable]
    @ObservedObject var playerViewModel: PlayerViewModel


    var body: some View {
        List {ForEach(tracks, id: \.id) { track in
            let isCurrent = playerViewModel.isCurrent(track, in: .player)
            let isPlaying = isCurrent && playerViewModel.isPlaying

            PlayerTrackRowView(
                track: track,
                isCurrent: isCurrent,
                isPlaying: isPlaying,
                onTap: {
                    if isCurrent {
                        playerViewModel.togglePlayPause()
                    } else {
                        playerViewModel.play(track: track, context: tracks)
                    }
                }
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
