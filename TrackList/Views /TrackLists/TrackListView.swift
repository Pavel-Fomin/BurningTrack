//
//  TrackListView.swift
//  TrackList
//
//  Вью для отображения списка треков
//
//  Created by Pavel Fomin on 29.04.2025.
//

import SwiftUI
import AVFoundation

struct TrackListView: View {
    @ObservedObject var trackListViewModel: TrackListViewModel
    @ObservedObject var playerViewModel: PlayerViewModel
    @Environment(\.colorScheme) var colorScheme
    
    
    var body: some View {
        ZStack {
            List {
                TrackListRowsView(
                    tracks: trackListViewModel.tracks,
                    metadataProvider: trackListViewModel,
                    playerViewModel: playerViewModel,
                    onTap: { track in
                        if track.isAvailable {
                            if (playerViewModel.currentTrackDisplayable as? Track)?.id == track.id {
                                playerViewModel.togglePlayPause()
                            } else {
                                playerViewModel.play(track: track, context: trackListViewModel.tracks)
                            }
                        } else {print("❌ Трек недоступен: \(track.title ?? track.fileName)")}
                    },
                    onDelete: { indexSet in
                        trackListViewModel.removeTrack(at: indexSet)
                    },
                    onMove: { source, destination in
                        trackListViewModel.moveTrack(from: source, to: destination)
                    }
                )
            }
            
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 88)
            }
        }
    }
}

            // MARK: - Компонент строк треков

            private struct TrackListRowsView: View {
                let tracks: [Track]
                let metadataProvider: TrackMetadataProviding
                let playerViewModel: PlayerViewModel
                let onTap: (Track) -> Void
                let onDelete: (IndexSet) -> Void
                let onMove: (IndexSet, Int) -> Void

                var body: some View {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        TrackListRowWrapper(
                            track: track,
                            index: index,
                            tracksContext: tracks,
                            metadataProvider: metadataProvider,
                            playerViewModel: playerViewModel,
                            onTap: onTap,
                            onDelete: onDelete
                        )
                    }
                    .onMove(perform: onMove)
                }
            }
