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
            playerViewModel: playerViewModel
        )
                }
            }

