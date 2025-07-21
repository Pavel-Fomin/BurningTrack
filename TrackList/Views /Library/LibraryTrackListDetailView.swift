//
//  LibraryTrackListDetailView.swift
//  TrackList
//
//  Created by Pavel Fomin on 10.07.2025.
//

import SwiftUI

struct LibraryTrackListDetailView: View {
    let trackListId: UUID

    var body: some View {
        let trackList = TrackListManager.shared.getTrackListById(trackListId)

        List(trackList.tracks) { track in
            TrackRowView(
                track: track,
                isCurrent: false,
                isPlaying: false,
                onTap: {               
                }
            )
        }
        .navigationTitle(trackList.name)
    }
}
