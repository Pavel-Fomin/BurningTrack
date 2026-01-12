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
    let trackListNamesById: [UUID: [String]]

    let playerViewModel: PlayerViewModel
    
    let metadataProvider: TrackMetadataProviding

    let isScrollingFast: Bool
    let revealedTrackID: UUID?
    
    let isSelecting: Bool
    @Binding var selection: Set<UUID>

    var body: some View {
        Section(header: Text(title).font(.headline).id(title)) {
            ForEach(tracks, id: \.id) { track in

                LibraryTrackRowWrapper(
                    track: track,
                    allTracks: allTracks,
                    trackListViewModel: trackListViewModel,
                    trackListNamesById: trackListNamesById,
                    metadataProvider: metadataProvider,
                    isScrollingFast: isScrollingFast,
                    isRevealed: track.id == revealedTrackID,
                    showsSelection: isSelecting,
                    isSelected: selection.contains(track.id),
                    onToggleSelection: {
                        if selection.contains(track.id) {
                            selection.remove(track.id)
                        } else {
                            selection.insert(track.id)
                        }
                    },
                    playerViewModel: playerViewModel
                )
                .id(track.id)
            }
        }
        .id(title)
    }
}
