//
//  LibraryTrackRow.swift
//  TrackList
//
//  Created by Pavel Fomin on 05.07.2025.
//

import SwiftUI

struct LibraryTrackRow: View {
    let track: LibraryTrack
    let playerViewModel: PlayerViewModel
    let onTap: () -> Void

    var body: some View {
        TrackRowView(
            track: track,
            isCurrent: track.id == playerViewModel.currentTrackDisplayable?.id,
            isPlaying: playerViewModel.isPlaying && track.id == playerViewModel.currentTrackDisplayable?.id,
            onTap: onTap
        )
    }
}
