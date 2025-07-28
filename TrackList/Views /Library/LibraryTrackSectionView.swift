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
    
    @ObservedObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var toast: ToastManager
    
    var body: some View {
        
        Section(header: Text(title).font(.headline)) {
            ForEach(tracks, id: \.id) { track in
                let isCurrent = playerViewModel.currentTrackDisplayable?.id == track.id
                let isPlaying = isCurrent && playerViewModel.isPlaying
                
                let trackListNames = trackListNamesByURL[track.url] ?? []
                
                TrackRowView(
                    track: track,
                    isCurrent: isCurrent,
                    isPlaying: isPlaying,
                    onTap: {
                        if let current = playerViewModel.currentTrackDisplayable as? LibraryTrack,
                           current.id == track.id {
                            playerViewModel.togglePlayPause()
                        } else {
                            playerViewModel.play(track: track, context: allTracks)
                        }
                    },
                    
                    swipeActionsLeft: [
                        CustomSwipeAction(
                            label: "В плеер",
                            systemImage: "square.and.arrow.down",
                            role: .none,
                            tint: .blue,
                            handler: {
                                var imported = track.original
                                
                                if let image = track.artwork {
                                    let artworkId = UUID()
                                    ArtworkManager.saveArtwork(image, id: artworkId)
                                    imported.artworkId = artworkId
                                }
                                
                                let newTrack = Track(
                                    id: imported.id,
                                    url: track.url,
                                    artist: imported.artist,
                                    title: imported.title,
                                    duration: imported.duration,
                                    fileName: imported.fileName,
                                    artworkId: imported.artworkId,
                                    isAvailable: true
                                )
                                
                                PlaylistManager.shared.tracks.append(newTrack)
                                PlaylistManager.shared.saveToDisk()
                                
                                toast.show(ToastData(
                                    style: .track(title: track.title ?? track.fileName, artist: track.artist ?? ""),
                                    artwork: track.artwork
                                ))
                            },
                            labelType: .textOnly
                        )
                    ],
                    trackListNames: trackListNames
                )
                .environmentObject(toast)
            }
        }
    }
}
