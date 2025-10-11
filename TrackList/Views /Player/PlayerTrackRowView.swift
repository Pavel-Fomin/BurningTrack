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
    @EnvironmentObject var sheetManager: SheetManager
    
    var body: some View {
        TrackRowView(
            track: track,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            isHighlighted: sheetManager.highlightedTrackID == track.id,
            artwork: artwork,
            title: track.title ?? track.fileName,
            artist: track.artist ?? "",
            onTap: onTap
        )
        .task(id: track.url) {
            artwork = await ArtworkLoader.loadIfNeeded(current: artwork, url: track.url)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                if let index = PlaylistManager.shared.tracks.firstIndex(where: { $0.id == track.id }) {
                    PlaylistManager.shared.remove(at: index)
                }
            } label: {
                Label("Удалить", systemImage: "trash")
            }
            
            Button {
                SheetManager.shared.presentTrackActions(track: track, context: .player)
            } label: {
                Label("Ещё", systemImage: "ellipsis")
            }
            .tint(.gray)
        }
    }
}
