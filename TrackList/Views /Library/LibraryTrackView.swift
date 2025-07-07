//
//  LibraryTrackView.swift
//  TrackList
//
//  Отображает список треков внутри секции (без заголовка).
//
//  Created by Pavel Fomin on 07.07.2025.
//

import SwiftUI

struct LibraryTrackView: View {
    let tracks: [LibraryTrack]
    let allTracks: [LibraryTrack]
    let playerViewModel: PlayerViewModel
    
    var body: some View {
        ForEach(tracks) { track in
            LibraryTrackRow(
                track: track,
                playerViewModel: playerViewModel,
                onTap: {
                    if track.isAvailable {
                        if playerViewModel.currentTrackDisplayable?.id == track.id {
                            playerViewModel.togglePlayPause()
                        } else {
                            playerViewModel.play(track: track, context: allTracks)
                        }
                    } else {
                        print("❌ Трек недоступен: \(track.title ?? track.fileName)")
                    }
                }
            )
        }
    }
}
