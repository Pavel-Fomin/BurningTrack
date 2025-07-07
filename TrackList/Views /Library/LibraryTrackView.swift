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
    let playerViewModel: PlayerViewModel

    var body: some View {
        ForEach(tracks) { track in
            let isCurrent = playerViewModel.currentTrackDisplayable?.id == track.id
            let isPlaying = isCurrent && playerViewModel.isPlaying

            LibraryTrackRow(
                track: track,
                isPlaying: isPlaying,
                isCurrent: isCurrent,
                onTap: {
                    if track.isAvailable {
                        if isCurrent {
                            playerViewModel.togglePlayPause()
                        } else {
                            playerViewModel.play(track: track)
                        }
                    } else {
                        print("❌ Трек недоступен: \(track.title ?? track.fileName)")
                    }
                }
            )
        }
    }
}
