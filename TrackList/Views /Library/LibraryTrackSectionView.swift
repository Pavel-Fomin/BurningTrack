//
//  LibraryTrackSectionView.swift
//  TrackList
//
//  Cекция треков с разделителем
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
    
    @ObservedObject var coordinator: LibraryCoordinator
    @EnvironmentObject var toast: ToastManager
    @EnvironmentObject var sheetManager: SheetManager

    var body: some View {
        Section(header: Text(title).font(.headline)) {
            ForEach(tracks, id: \.id) { track in
                LibraryTrackRowWrapper(
                    track: track,
                    allTracks: allTracks,
                    trackListViewModel: trackListViewModel,
                    trackListNamesByURL: trackListNamesByURL,
                    metadata: metadataByURL[track.url],
                    isScrollingFast: isScrollingFast,
                    isRevealed: track.id == revealedTrackID,
                    coordinator: coordinator,
                    playerViewModel: playerViewModel
                )
                .id(track.id)
                .environmentObject(toast)
                .environmentObject(sheetManager)
            }
        }
    }
}
