//
//  MiniPlayerView.swift
//  TrackList
//
//  Мини-плеер
//
//  Created by Pavel Fomin on 28.04.2025.
//

import Foundation
import SwiftUI
import AVKit

struct AVRoutePickerViewWrapper: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.activeTintColor = .label
        view.tintColor = .secondaryLabel
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

struct MiniPlayerView: View {
    
    let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
    
    var trackListViewModel: TrackListViewModel?

    @ObservedObject var playerViewModel: PlayerViewModel

    var body: some View {

        guard let track = playerViewModel.currentTrackDisplayable else { return AnyView(EmptyView()) }

        let staticState = playerViewModel.miniPlayerStaticState
        

        let title = staticState?.title ?? track.fileName
        let artist = staticState?.artist ?? "Неизвестный артист"
        let artwork = staticState?.artwork

        return AnyView(
            VStack {

                MiniPlayerHeaderView(
                    artwork: artwork,
                    title: title,
                    artist: artist,
                    onTap: {
                        playerViewModel.togglePlayPause()
                    },
                    onSwipeNext: {
                        playerViewModel.playNextTrack()
                    },
                    onSwipePrevious: {
                        playerViewModel.playPreviousTrack()
                    }
                )

                MiniPlayerProgressView(
                    currentTime: playerViewModel.miniPlayerCurrentTime,
                    duration: playerViewModel.miniPlayerDuration,
                    onSeek: { time in
                        playerViewModel.seek(to: time)
                    }
                )
            }
                .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: MiniPlayerHeightPreferenceKey.self, value: proxy.size.height)
                        }
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                )
    }
}
