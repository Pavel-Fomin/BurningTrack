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
    @Environment(\.scenePhase) private var scenePhase
    
    
    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
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
                        onRenameTrack: { rowId, strategy in
                            trackListViewModel.renameTrack(
                                rowId: rowId,
                                strategy: strategy
                            )
                        },
                        onMove: { source, destination in
                            trackListViewModel.moveTrack(from: source, to: destination)
                        }
                    )
                }
                
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .onAppear {
                    scrollToCurrentTrackIfNeeded(using: proxy, animated: false)
                }
                .onChange(of: playerViewModel.currentTrackDisplayable?.id) { _, _ in
                    scrollToCurrentTrackIfNeeded(using: proxy, animated: true)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    scrollToCurrentTrackIfNeeded(using: proxy, animated: true)
                }
            }
        }
    }
    
    private func scrollToCurrentTrackIfNeeded(using proxy: ScrollViewProxy, animated: Bool) {
        guard playerViewModel.currentContext == .trackList else { return }
        guard let currentTrackId = playerViewModel.currentTrackDisplayable?.id else { return }
        guard trackListViewModel.tracks.contains(where: { $0.id == currentTrackId }) else { return }

        if animated {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(currentTrackId, anchor: .center)
            }
        } else {
            proxy.scrollTo(currentTrackId, anchor: .center)
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
                let onRenameTrack: (UUID, FileRenameStrategy) -> Void
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
                            onDelete: onDelete,
                            onRenameTrack: onRenameTrack
                        )
                        .id(track.id)
                    }
                    .onMove(perform: onMove)
                }
            }
