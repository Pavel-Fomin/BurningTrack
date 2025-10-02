//
//  PlayerTrackRowView.swift
//  TrackList
//
//  Created by Pavel Fomin on 03.08.2025.
//

import Foundation
import SwiftUI

struct PlayerTrackRowView: View {
    let track: any TrackDisplayable
    let isCurrent: Bool
    let isPlaying: Bool
    let onTap: () -> Void

    @State private var artwork: CGImage? = nil

    var body: some View {
        TrackRowView(
            track: track,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            isHighlighted: false,
            artwork: artwork,
            title: track.title ?? track.fileName,
            artist: track.artist ?? "",
            onTap: onTap,
            swipeActionsLeft: [
                CustomSwipeAction(
                    label: "Удалить",
                    systemImage: "trash",
                    role: .destructive,
                    tint: .red,
                    handler: {
                        if let index = PlaylistManager.shared.tracks.firstIndex(where: { $0.id == track.id }) {
                            PlaylistManager.shared.remove(at: index)
                        }
                    },
                    labelType: .iconOnly
                )
            ],
            swipeActionsRight: [],
            trackListNames: [],
            useNativeSwipeActions: false
        )
        .task(id: track.url) {
            artwork = await ArtworkLoader.loadIfNeeded(current: artwork, url: track.url)
        }
        
        }
    }

