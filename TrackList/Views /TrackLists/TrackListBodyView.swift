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
    
    
    // MARK: - Отображение треков выбранного треклиста
    
    private func trackListView() -> some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(trackListViewModel.tracks.enumerated()), id: \.element.id) { index, track in
                    let isCurrent = (playerViewModel.currentTrackDisplayable as? Track)?.id == track.id
                    
                    RowWrapper(
                        track: track,
                        playerViewModel: playerViewModel,
                        trackListViewModel: trackListViewModel,
                        onTap: {
                            if track.isAvailable {
                                if isCurrent {
                                    playerViewModel.togglePlayPause()
                                } else {
                                    playerViewModel.play(track: track, context: trackListViewModel.tracks)
                                }
                            }
                        }
                    )
                }
                
            }
        }
    }
    
    private struct RowWrapper: View {
        let track: Track
        let playerViewModel: PlayerViewModel
        let trackListViewModel: TrackListViewModel
        let onTap: () -> Void
        
        var body: some View {
            TrackRowView(
                track: track,
                isCurrent: track.id == playerViewModel.currentTrackDisplayable?.id,
                isPlaying: playerViewModel.isPlaying && track.id == playerViewModel.currentTrackDisplayable?.id,
                artwork: trackListViewModel.artworkByURL[track.url],
                title: track.title ?? track.fileName,
                artist: track.artist ?? "",
                onTap: onTap,
                swipeActionsLeft: [],
                swipeActionsRight: [],
                trackListNames: [],
                useNativeSwipeActions: false
            )
        }
    }
}
