//
//  TrackListView.swift
//  TrackList
//
//  Основная вью для отображения списка треков внутри выбранного треклиста
//  Отвечает за вывод строк треков, удаление, перемещение, выделение текущего трека в плеере
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
                    }
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
    
    // MARK: - Компонент строк треков
    
    private struct TrackListRowsView: View {
        let tracks: [Track]
        let playerViewModel: PlayerViewModel
        let onTap: (Track) -> Void
        let onDelete: (IndexSet) -> Void
        let onMove: (IndexSet, Int) -> Void
        
        var body: some View {
            ForEach(tracks) { track in
                TrackRowView(
                    track: track,
                    isCurrent: track.id == playerViewModel.currentTrackDisplayable?.id,
                    isPlaying: playerViewModel.isPlaying && track.id == playerViewModel.currentTrackDisplayable?.id,
                    onTap: { onTap(track) }
                )
                .padding(.vertical, 4)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
            }
            .onDelete(perform: onDelete)
            .onMove(perform: onMove)
        }
    }
}
