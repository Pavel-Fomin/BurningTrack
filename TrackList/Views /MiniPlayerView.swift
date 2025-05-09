//
//  MiniPlayerView.swift
//  TrackList
//
//  Created by Pavel Fomin on 28.04.2025.
//

import Foundation
import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @ObservedObject var trackListViewModel: TrackListViewModel

    var body: some View {
        if let track = playerViewModel.currentTrack {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    if let artwork = track.artwork {
                        Image(uiImage: artwork)
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                            .frame(width: 44, height: 44)
                            .cornerRadius(6)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 44, height: 44)
                            .cornerRadius(6)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.artist ?? "Неизвестный артист")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Text(track.title ?? track.fileName)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        Button(action: {
                            // Пока отключено
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.title2)
                        }

                        Button(action: {
                            playerViewModel.togglePlayPause()
                        }) {
                            Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                        }

                        Button(action: {
                            // Пока отключено
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.title2)
                        }
                    }
                }

                HStack {
                    Text(formatTimeSmart(playerViewModel.currentTime))
                        .font(.caption)
                        .frame(width: 40, alignment: .leading)

                    Slider(
                        value: Binding(
                            get: { playerViewModel.currentTime },
                            set: { newValue in
                                playerViewModel.currentTime = newValue
                                playerViewModel.seek(to: newValue)
                            }
                        ),
                        in: 0...max(playerViewModel.trackDuration, playerViewModel.currentTime)
                    )
                    .accentColor(.blue)

                    Text("-\(formatTimeSmart(playerViewModel.trackDuration - playerViewModel.currentTime))")
                        .font(.caption)
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
    }
}

struct MiniPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        MiniPlayerView(
            playerViewModel: PlayerViewModel(),
            trackListViewModel: TrackListViewModel()
        )
        .padding()
        .previewDisplayName("Mini Player Preview")
    }
}
