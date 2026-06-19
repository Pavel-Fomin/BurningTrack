//
//  MiniPlayerView.swift
//  TrackList
//
//  Мини-плеер
//
//  Created by Pavel Fomin on 28.04.2025.
//

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

    @ObservedObject var playerViewModel: PlayerViewModel

    /// Почти прозрачная зона, которая гасит жесты только в пустых местах карточки.
    private var hitTestBlocker: some View {
        Color.black.opacity(0.001)
            .frame(height: 8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in }
            )
    }

    var body: some View {
        guard let track = playerViewModel.currentTrackDisplayable else { return AnyView(EmptyView()) }
        let staticState = playerViewModel.miniPlayerStaticState
        let title = staticState?.title ?? track.fileName
        let artist = staticState?.artist ?? ""
        let artwork = staticState?.artwork

        return AnyView(
            VStack(spacing: 0) {
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

                hitTestBlocker

                MiniPlayerProgressView(
                    currentTime: playerViewModel.miniPlayerCurrentTime,
                    duration: playerViewModel.miniPlayerDuration,
                    onSeek: { time in
                        playerViewModel.seek(to: time)
                    }
                )

                hitTestBlocker
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: shape)
            .clipShape(shape)
            .contentShape(shape)
            .padding(.horizontal, 16)
        )
    }
}
