//
//  PlayerPlaylistView.swift
//  TrackList
//
//  Обёртка над PlayerView — подписка на PlaylistManager
//  Передаёт данные в UI и управляет действиями
//
//  Created by Pavel Fomin on 15.07.2025.
//

import Foundation
import SwiftUI

struct PlayerPlaylistView: View {
    @ObservedObject private var manager = PlaylistManager.shared
    @ObservedObject var playerViewModel: PlayerViewModel

    var body: some View {
        PlayerView(
            tracks: manager.tracks,
            currentTrack: playerViewModel.currentTrackDisplayable as? Track,
            isPlaying: playerViewModel.isPlaying,
            onTrackTap: { track in
                            if let current = playerViewModel.currentTrackDisplayable as? Track,
                               current.id == track.id {
                                playerViewModel.togglePlayPause()
                            } else {
                                playerViewModel.play(
                                    track: track,
                                    context: manager.tracks
                                )
                            }
                },artworkProvider: ArtworkProvider.shared

            )
        }
    }
