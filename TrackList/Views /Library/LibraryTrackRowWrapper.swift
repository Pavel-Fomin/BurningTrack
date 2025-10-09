//
//  LibraryTrackRowWrapper.swift
//  TrackList
//
//  Обёртка для TrackRowView с реакцией на изменения playerViewModel
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
    let isScrollingFast: Bool
    
    @State private var artwork: CGImage? = nil
    
    @ObservedObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var toast: ToastManager
    @EnvironmentObject var sheetManager: SheetManager
    
    private var isCurrent: Bool {
        playerViewModel.isCurrent(track, in: .library)
    }
    
    private var isPlaying: Bool {
        isCurrent && playerViewModel.isPlaying
    }
    
    private var trackListNames: [String] {
        trackListNamesByURL[track.url] ?? []
    }
    
    private var isHighlighted: Bool {
        sheetManager.highlightedTrackID == track.id
    }
    
    var body: some View {
        TrackRowView(
            track: track,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            isHighlighted: isHighlighted,
            artwork: artwork,
            title: metadata?.title ?? track.original.title,
            artist: metadata?.artist ?? track.original.artist,
            onTap: {
                if isCurrent {
                    playerViewModel.togglePlayPause()
                } else {
                    playerViewModel.play(track: track, context: allTracks)
                }
            },
            trackListNames: trackListNames
        )
        .task(id: track.url.absoluteString + "|" + (isScrollingFast ? "1" : "0")) {
            if isScrollingFast || artwork != nil { return }
            
            try? await Task.sleep(nanoseconds: 60_000_000)
            
            let img = await ArtworkLoader.loadIfNeeded(current: artwork, url: track.url)
            if let img {
                await MainActor.run { artwork = img }
            }
            
            if metadata == nil {
                _ = await TrackMetadataCacheManager.shared.loadMetadata(for: track.url)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                let imported = track.original
                if let playerTrack = PlayerTrack(from: imported) {
                    PlaylistManager.shared.tracks.append(playerTrack)
                    PlaylistManager.shared.saveToDisk()
                    
                    toast.show(ToastData(
                        style: .track(title: track.title ?? track.fileName, artist: track.artist ?? ""),
                        artwork: track.artwork
                    ))
                }
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
            
            Button {
                sheetManager.highlightedTrackID = track.id
                sheetManager.presentTrackActions(track: track, context: .library)
            } label: {
                Image(systemName: "ellipsis")
            }
            .tint(.gray)
        }
    }
}
