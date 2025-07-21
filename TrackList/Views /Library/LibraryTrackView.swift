//
//  LibraryTrackView.swift
//  TrackList
//
//  Отображает список треков внутри секции (без заголовка).
//
//  Created by Pavel Fomin on 07.07.2025.
//

import SwiftUI
import Foundation

struct LibraryTrackView: View {
    let tracks: [LibraryTrack]
    let allTracks: [LibraryTrack]
    @ObservedObject var playerViewModel: PlayerViewModel
    
    var body: some View {
        ForEach(tracks) { track in
            let currentTrack = playerViewModel.currentTrackDisplayable as? LibraryTrack
            let isCurrent = currentTrack?.url.path == track.url.path
            
            
            LibraryTrackRow(
                track: track,
                isCurrent: isCurrent,
                isPlaying: isCurrent && playerViewModel.isPlaying,
                onTap: {
                    guard track.isAvailable else { return }
                    
                    if isCurrent {
                        print("⏯ Повторный тап — togglePlayPause()")
                        playerViewModel.togglePlayPause()
                    } else {
                        print("▶️ Новый трек — play()")
                        playerViewModel.play(track: track, context: allTracks)
                    }
                }
            )
        }
    }
}
