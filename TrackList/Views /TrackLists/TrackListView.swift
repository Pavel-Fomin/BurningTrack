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
    @StateObject private var artworkProvider = ArtworkProvider()
    
    var body: some View {
        ZStack {
            List {
                TrackListRowsView(
                    tracks: trackListViewModel.tracks,
                    playerViewModel: playerViewModel,
                    onTap: { track in
                        if track.isAvailable {
                            if (playerViewModel.currentTrackDisplayable as? Track)?.id == track.id {
                                playerViewModel.togglePlayPause()
                            } else {
                                playerViewModel.play(track: track, context: trackListViewModel.tracks)
                            }
                        } else {
                            print("❌ Трек недоступен: \(track.title ?? track.fileName)")
                        }
                    },
                    onDelete: { indexSet in
                        trackListViewModel.removeTrack(at: indexSet)
                    },
                    onMove: { source, destination in
                        trackListViewModel.moveTrack(from: source, to: destination)
                    },
                    artworkProvider: artworkProvider
                    
                )
            }
            
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                
                // Тост
                if let toast = trackListViewModel.toastData {
                    ToastView(data: toast)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 24)
                }
            }
            .frame(maxHeight: .infinity)
            .animation(.easeInOut, value: trackListViewModel.toastData?.message ?? "")
            .sheet(isPresented: $trackListViewModel.isShowingSaveSheet) {
                SaveTrackListSheet(
                    isPresented: $trackListViewModel.isShowingSaveSheet,
                    name: $trackListViewModel.newTrackListName
                ) {
                    if let id = trackListViewModel.currentListId {
                        TrackListManager.shared.renameTrackList(id: id, to: trackListViewModel.newTrackListName)
                    }
                }
            }
        }
    }


// MARK: - Компонент строк треков
        
        private struct TrackListRowsView: View {
            let tracks: [Track]
            let playerViewModel: PlayerViewModel
            let onTap: (Track) -> Void
            let onDelete: (IndexSet) -> Void
            let onMove: (IndexSet, Int) -> Void
            let artworkProvider: ArtworkProvider
            
            var body: some View {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    TrackRowView(
                        track: track,
                        isCurrent: track.id == playerViewModel.currentTrackDisplayable?.id,
                        isPlaying: playerViewModel.isPlaying && track.id == playerViewModel.currentTrackDisplayable?.id,
                        artwork: artworkProvider.artwork(for: track.url),
                        onTap: { onTap(track) }
                    )
                    .onAppear {
                        artworkProvider.loadArtworkIfNeeded(for: track.url)
                    }
                    
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onDelete(IndexSet(integer: index))
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
                .onMove(perform: onMove)
            }
        }

    

