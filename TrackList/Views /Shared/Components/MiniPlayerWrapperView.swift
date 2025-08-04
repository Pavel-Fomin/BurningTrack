//
//  MiniPlayerWrapperView.swift
//  TrackList
//
// Обёртка для MiniPlayerView
//
//  Created by Pavel Fomin on 13.07.2025.
//

import Foundation
import SwiftUI


struct MiniPlayerWrapperView<Content: View>: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    var trackListViewModel: TrackListViewModel?
    let content: Content
    
    init(
        playerViewModel: PlayerViewModel,
        trackListViewModel: TrackListViewModel? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.playerViewModel = playerViewModel
        self.trackListViewModel = trackListViewModel
        self.content = content()
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            content
            
            if playerViewModel.currentTrackDisplayable != nil {
                MiniPlayerView(
                    trackListViewModel: trackListViewModel,
                    playerViewModel: playerViewModel
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 56)
            }
        }
    }
}
