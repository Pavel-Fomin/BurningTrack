//
//  TrackListBodyView.swift
//  TrackList
//
//  Основная вьюха, отображающая список треков
//
//  Created by Pavel Fomin on 29.04.2025.
//

import SwiftUI

struct TrackListBodyView: View {
    @ObservedObject var trackListViewModel: TrackListViewModel
    @ObservedObject var playerViewModel: PlayerViewModel

    var body: some View {
        
        VStack {
            trackListView()
        }
        .onAppear {
            print("👀 TrackListBodyView появился, загружаем треки")
            trackListViewModel.loadTracks()
        }
    }

    private func trackListView() -> some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(trackListViewModel.tracks.enumerated()), id: \.element.id) { index, track in
                    let isCurrent = playerViewModel.currentTrack?.id == track.id

                    TrackRowView(
                        track: track,
                        isPlaying: playerViewModel.isPlaying,
                        isCurrent: isCurrent,
                        onTap: {
                            print("🖱️ Row tapped:", track.title)
                            if isCurrent {
                                playerViewModel.togglePlayPause()
                            } else {
                                playerViewModel.play(track: track)
                            }
                        }
                    )
                }
                .onDelete { indexSet in
                    trackListViewModel.removeTrack(at: indexSet)
                }
                .onMove { indices, newOffset in
                    trackListViewModel.moveTrack(from: indices, to: newOffset)
                }
            }
        }
    }
}
