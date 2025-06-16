//
//  TrackListBodyView.swift
//  TrackList
//
//  Основная View, отображающая список треков в текущем плейлисте
//
//  Created by Pavel Fomin on 29.04.2025.
//

import SwiftUI

// MARK: - Основное тело списка треков
struct TrackListBodyView: View {
    @ObservedObject var trackListViewModel: TrackListViewModel   // ViewModel треклиста
    @ObservedObject var playerViewModel: PlayerViewModel         // ViewModel плеера

    var body: some View {
        VStack {
            trackListView()
        }
        .onAppear {
            print("👀 TrackListBodyView появился, загружаем треки")
            trackListViewModel.loadTracks()
        }
    }

    // MARK: - Отображение списка треков
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
                            print("🖱️ Row tapped:", track.title ?? track.fileName)
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
