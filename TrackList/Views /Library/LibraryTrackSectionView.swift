//
//  LibraryTrackSectionView.swift
//  TrackList
//
//  Секция треков с заголовком.
//  Чистый UI — не содержит навигации.
//  Навигация обрабатывается уровнем выше (FolderView / LibraryScreen).
//
//  Created by Pavel Fomin on 07.07.2025.
//

import SwiftUI

struct LibraryTrackSectionView: View {

    let title: String
    let tracks: [LibraryTrack]
    let allTracks: [LibraryTrack]

    let trackListViewModel: TrackListViewModel
    let trackListNamesByURL: [URL: [String]]

    let playerViewModel: PlayerViewModel
    let metadataByURL: [URL: TrackMetadataCacheManager.CachedMetadata]

    let isScrollingFast: Bool
    let revealedTrackID: UUID?
    let folderViewModel: LibraryFolderViewModel

    var body: some View {
        Section(header: Text(title).font(.headline).id(title)) {
            ForEach(tracks, id: \.id) { track in

                LibraryTrackRowWrapper(
                    track: track,
                    allTracks: allTracks,
                    trackListViewModel: trackListViewModel,
                    trackListNamesByURL: trackListNamesByURL,
                    metadata: metadataByURL[track.url],
                    onMetadataLoaded: { url, meta in folderViewModel.setMetadata(meta, for: url)},
                    isScrollingFast: isScrollingFast,
                    isRevealed: track.id == revealedTrackID,
                    playerViewModel: playerViewModel
                )
                .id(track.id)
            }
        }
        .id(title)
    }
}
