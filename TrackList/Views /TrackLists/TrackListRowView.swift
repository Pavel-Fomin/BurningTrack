//
//  TrackListRowView.swift
//  TrackList
//
//  Created by Pavel Fomin on 03.08.2025.
//

import SwiftUI
import Foundation

struct TrackListRowView: View {
    let track: Track
    let isCurrent: Bool
    let isPlaying: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var artwork: CGImage? = nil
    @ObservedObject private var sheetManager = SheetManager.shared
    
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
        
        .task(id: track.id) {
            artwork = await ArtworkLoader.loadIfNeeded(
                current: artwork,
                trackId: track.id
            )
        }
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Удалить", systemImage: "trash")
            }

            Button {
                SheetManager.shared.presentTrackActions(track: track, context: .tracklist)
            } label: {
                Label("Ещё", systemImage: "ellipsis")
            }
            .tint(.gray)
        }
    }
}
