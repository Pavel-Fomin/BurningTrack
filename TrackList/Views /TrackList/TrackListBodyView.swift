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
    
    // ViewModel треклиста
    @ObservedObject var trackListViewModel: TrackListViewModel
    
    // ViewModel плеера
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
    
    
// MARK: - Отображение списка треков
    
    private func trackListView() -> some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(trackListViewModel.tracks.enumerated()), id: \.element.id) { index, track in
                    let isCurrent = (playerViewModel.currentTrackDisplayable as? Track)?.id == track.id
                    
                    
                    RowWrapper(
                        track: track,
                        playerViewModel: playerViewModel,
                        onTap: {
                            if track.isAvailable {
                                if isCurrent {
                                    playerViewModel.togglePlayPause()
                                } else {
                                    playerViewModel.play(track: track)
                                }
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
    
    private struct RowWrapper: View {
        let track: Track
        let playerViewModel: PlayerViewModel
        let onTap: () -> Void
        
        var body: some View {
            TrackRowView(
                playerViewModel: playerViewModel,
                track: track,
                onTap: onTap
            )
        }
    }
}
