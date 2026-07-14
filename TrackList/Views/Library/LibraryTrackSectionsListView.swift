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
    let playbackSource: PlaybackContextSource?

    let trackListNamesById: [UUID: [String]]
    
    let metadataProvider: TrackMetadataProviding
    
    let playerViewModel: PlayerViewModel
    
    let isScrollingFast: Bool
    let revealedTrackID: UUID?
    let onRenameTrack: (UUID, FileRenameStrategy) -> Void
    
    let isSelecting: Bool
    
    @Binding var selection: OrderedSelection<UUID>

    var body: some View {
        ForEach(sections, id: \.id) { section in
            LibraryTrackSectionView(
                id: section.id,
                title: section.title,
                showsHeader: section.showsHeader,
                tracks: section.tracks,
                allTracks: allTracks,
                playbackSource: playbackSource,
                trackListNamesById: trackListNamesById,
                playerViewModel: playerViewModel,
                metadataProvider: metadataProvider,
                isScrollingFast: isScrollingFast,
                revealedTrackID: revealedTrackID,
                onRenameTrack: onRenameTrack,
                isSelecting: isSelecting,
                selection: $selection
               
            )
        }
    }
}
