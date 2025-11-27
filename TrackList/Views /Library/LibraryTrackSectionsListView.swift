//
//  LibraryTrackSectionsListView.swift
//  TrackList
//
//  Отображает секции треков в папке (по дате).
//  Чистый UI-компонент — не содержит навигации.
//  Все переходы выполняются на уровне LibraryFolderView / LibraryScreen.
//
//  Created by Pavel Fomin on 08.08.2025.
//

import SwiftUI

struct LibraryTrackSectionsListView: View {

    let sections: [TrackSection]
    let allTracks: [LibraryTrack]

    let trackListViewModel: TrackListViewModel
    let trackListNamesByURL: [URL: [String]]
    let metadataByURL: [URL: TrackMetadataCacheManager.CachedMetadata]

    let playerViewModel: PlayerViewModel
    let isScrollingFast: Bool

    let revealedTrackID: UUID?
    let folderViewModel: LibraryFolderViewModel

    var body: some View {
        ForEach(sections, id: \.id) { section in
            LibraryTrackSectionView(
                title: section.title,
                tracks: section.tracks,
                allTracks: allTracks,
                trackListViewModel: trackListViewModel,
                trackListNamesByURL: trackListNamesByURL,
                playerViewModel: playerViewModel,
                metadataByURL: metadataByURL,
                isScrollingFast: isScrollingFast,
                revealedTrackID: revealedTrackID,
                folderViewModel: folderViewModel
            )
        }
    }
}
