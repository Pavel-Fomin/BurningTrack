//
//  LibraryTrackRowWrapper.swift
//  TrackList
//
//  Обёртка для TrackRowView с реакцией на изменения playerViewModel
//
//
//  Created by Pavel Fomin on 03.08.2025.
//

import SwiftUI

struct LibraryTrackRowWrapper: View {
    let track: LibraryTrack
    let allTracks: [LibraryTrack]
    let trackListViewModel: TrackListViewModel
    let trackListNamesByURL: [URL: [String]]
    let metadata: TrackMetadataCacheManager.CachedMetadata?
    
    @State private var artwork: CGImage? = nil
    
    @ObservedObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var toast: ToastManager
    @EnvironmentObject var sheetManager: SheetManager

    var body: some View {
        let isCurrent = playerViewModel.currentTrackDisplayable?.id == track.id
        let isPlaying = isCurrent && playerViewModel.isPlaying
        let trackListNames = trackListNamesByURL[track.url] ?? []

        TrackRowView(
            track: track,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            artwork: artwork,
            title: metadata?.title ?? track.original.title,
            artist: metadata?.artist ?? track.original.artist,
            onTap: {
                if let current = playerViewModel.currentTrackDisplayable as? LibraryTrack,
                   current.id == track.id {
                    playerViewModel.togglePlayPause()
                } else {
                    playerViewModel.play(track: track, context: allTracks)
                }
            },
            trackListNames: trackListNames
        )
        .task {
            artwork = await TrackMetadataCacheManager.shared
                .loadMetadata(for: track.url)?
                .artwork
            

        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                let imported = track.original

                let newTrack = Track(
                    id: imported.id,
                    url: track.url,
                    artist: imported.artist,
                    title: imported.title,
                    duration: imported.duration,
                    fileName: imported.fileName,
                    isAvailable: true
                )

                PlaylistManager.shared.tracks.append(newTrack)
                PlaylistManager.shared.saveToDisk()

                toast.show(ToastData(
                    style: .track(title: track.title ?? track.fileName, artist: track.artist ?? ""),
                    artwork: track.artwork
                ))
                
            } label: {
                Text("В плеер")
            }
            .tint(.blue)

            Button {
                sheetManager.open(track: track)
            } label: {
                Text("В треклист")
            }
            .tint(.green)
        }
    }
}
