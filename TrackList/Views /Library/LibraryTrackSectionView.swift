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
    let artworkProvider: ArtworkProvider
    let artworkByURL: [URL: UIImage]
    let playerViewModel: PlayerViewModel
    let metadataByURL: [URL: TrackMetadataCacheManager.CachedMetadata]
    
    
    @EnvironmentObject var toast: ToastManager
    @EnvironmentObject var sheetManager: SheetManager
    
    
    // MARK: - Вью обёртка для одного трека
    
    var body: some View {
        Section(header: Text(title).font(.headline)) {
            ForEach(tracks, id: \.id) { track in
                LibraryTrackRowWrapper(
                    track: track,
                    allTracks: allTracks,
                    trackListViewModel: trackListViewModel,
                    trackListNamesByURL: trackListNamesByURL,
                    artworkProvider: artworkProvider,
                    metadata: metadataByURL[track.resolvedURL],
                    playerViewModel: playerViewModel
                )
                .environmentObject(toast)
                .environmentObject(sheetManager)
            }
        }
    }
}
