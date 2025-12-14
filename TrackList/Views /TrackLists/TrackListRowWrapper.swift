//
//  TrackListRowWrapper.swift
//  TrackList
//
//  Created by Pavel Fomin on 13.12.2025.
//
//
//


import SwiftUI
import Foundation

@MainActor
struct TrackListRowWrapper: View {

    let track: Track
    let index: Int
    let tracksContext: [Track]

    let metadataProvider: TrackMetadataProviding

    let playerViewModel: PlayerViewModel
    let onTap: (Track) -> Void
    let onDelete: (IndexSet) -> Void

    private var displayTrack: Track {
        let meta = metadataProvider.metadata(for: track.id)

        return Track(
            id: track.id,
            title: meta?.title ?? track.title,
            artist: meta?.artist ?? track.artist,
            duration: meta?.duration ?? track.duration,
            fileName: track.fileName,
            isAvailable: track.isAvailable
        )
    }

    var body: some View {
        let isCurrent = playerViewModel.isCurrent(track, in: .trackList)
        let isPlaying = isCurrent && playerViewModel.isPlaying

        TrackListRowView(
            track: displayTrack,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            onTap: { onTap(track) },
            onDelete: { onDelete(IndexSet(integer: index)) }
        )
        .task(id: track.id) {
            metadataProvider.requestMetadataIfNeeded(for: track.id)
        }
    }
}
