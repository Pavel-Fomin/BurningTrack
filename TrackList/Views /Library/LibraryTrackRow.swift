//
//  LibraryTrackRow.swift
//  TrackList
//
//  Created by Pavel Fomin on 05.07.2025.
//

import SwiftUI

struct LibraryTrackRow: View {
    let track: LibraryTrack
    let isPlaying: Bool
    let isCurrent: Bool
    let onTap: () -> Void

    var body: some View {
        TrackRowView(
            track: track as (any TrackDisplayable),
            isPlaying: isPlaying,
            isCurrent: isCurrent,
            onTap: onTap
        )
    }
}
