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
    
    var body: some View {
        TrackRowView(
            track: track,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            artwork: artwork,
            title: track.title ?? track.fileName,
            artist: track.artist ?? "",
            onTap: onTap
        )
        
        .task(id: track.url) {
            artwork = await ArtworkLoader.loadIfNeeded(current: artwork, url: track.url)
            
        }
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }
}
