//
//  LibraryTrackSectionView.swift
//  TrackList
//
//  Отображает секцию треков с разделителем
//
//  Created by Pavel Fomin on 07.07.2025.
//

//
//  LibraryTrackSectionView.swift
//  TrackList
//
//  Отображает секцию треков с разделителем
//

import SwiftUI

struct LibraryTrackSectionView: View {
    let title: String
    let tracks: [LibraryTrack]
    let allTracks: [LibraryTrack]
    let playerViewModel: PlayerViewModel
    let trackListViewModel: TrackListViewModel

    @EnvironmentObject var toast: ToastManager

    var body: some View {
        Section(header: Text(title).font(.headline)) {
            ForEach(tracks, id: \.id) { track in
                LibraryTrackRow(
                    track: track,
                    isCurrent: track.id == playerViewModel.currentTrackDisplayable?.id,
                    isPlaying: playerViewModel.isPlaying && track.id == playerViewModel.currentTrackDisplayable?.id,
                    onTap: {
                        print("📌 Tap на \(track.title ?? track.fileName)")

                        if let current = playerViewModel.currentTrackDisplayable as? LibraryTrack,
                           current.id == track.id {
                            print("✅ Повторный тап. isCurrent: true")
                            playerViewModel.togglePlayPause()
                        } else {
                            print("▶️ Новый трек — play()")
                            playerViewModel.play(track: track, context: allTracks)
                            
                            
                        }
                    }
                )
                .environmentObject(toast)
            }
        }
    }
}
