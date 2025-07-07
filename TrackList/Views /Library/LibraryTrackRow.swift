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
            playerViewModel: playerViewModel,
            track: track,
            onTap: onTap
        )
    }
}
