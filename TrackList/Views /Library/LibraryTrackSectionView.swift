//
//  LibraryTrackSectionView.swift
//  TrackList
//
//  Отображает секцию треков с заголовком по дате (например, "Сегодня").
//
//  Created by Pavel Fomin on 07.07.2025.
//

import SwiftUI

struct LibraryTrackSectionView: View {
    let title: String
    let tracks: [LibraryTrack]
    let playerViewModel: PlayerViewModel

    var body: some View {
        Section(header: Text(title).font(.subheadline).foregroundColor(.secondary)) {
            LibraryTrackView(tracks: tracks, playerViewModel: playerViewModel)
        }
    }
}
