//
// PlayerView.swift
// TrackList
//
// Экран плеера со списком треков
//
// Created by Pavel Fomin on 14.07.2025.
//


import Foundation
import SwiftUI
struct PlayerView: View {
    let tracks: [PlayerTrack]
    @ObservedObject var playerViewModel: PlayerViewModel
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ScrollViewReader { proxy in
            List {
                PlayerRowsView(
                    tracks: tracks,
                    playerViewModel: playerViewModel
                )
            }
            .safeAreaInset(edge: .bottom) {Color.clear.frame(height: 88)}
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
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
    private func scrollToCurrentTrackIfNeeded(using proxy: ScrollViewProxy, animated: Bool) {
        guard playerViewModel.currentContext == .player else { return }
        guard let currentTrackId = playerViewModel.currentTrackDisplayable?.id else { return }
        guard tracks.contains(where: { $0.id == currentTrackId }) else { return }
        if animated {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(currentTrackId, anchor: .center)
            }
        } else {
            proxy.scrollTo(currentTrackId, anchor: .center)
        }
    }
    // MARK: - Компонент строк плеера
    
    private struct PlayerRowsView: View {
        let tracks: [any TrackDisplayable]
        let playerViewModel: PlayerViewModel
        var body: some View {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { _, track in
                let isCurrent = playerViewModel.isCurrent(track, in: .player)
                let isPlaying = isCurrent && playerViewModel.isPlaying
                PlayerTrackRowWrapper(
                    track: track,
                    isCurrent: isCurrent,
                    isPlaying: isPlaying,
                    onTap: {
                        if isCurrent {
                            playerViewModel.togglePlayPause()
                        } else {
                            playerViewModel.play(track: track, context: tracks)
                        }
                    },
                    playerViewModel: playerViewModel
                )
                .id(track.id)
            }
            .onMove { from, to in
                let previousTracks = PlaylistManager.shared.tracks
                PlaylistManager.shared.tracks.move(fromOffsets: from, toOffset: to)
                guard PlaylistManager.shared.saveToDisk() else {
                    PlaylistManager.shared.tracks = previousTracks
                    ToastManager.shared.handle(.playlistSaveFailed)
                    return
                }
            }
        }
    }
}
