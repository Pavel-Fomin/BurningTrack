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
                playerViewModel: PlayerViewModel(trackListViewModel: .init()), /// передаем shared, если у нас синглтон
                track: track,
                onTap: { /// действие при тапе
                }
            )
        }
        .navigationTitle(trackList.name)
    }
}
