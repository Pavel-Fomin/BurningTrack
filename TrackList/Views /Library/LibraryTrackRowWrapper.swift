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
    let isRevealed: Bool
    
    @State private var artwork: CGImage? = nil
    
    @ObservedObject var coordinator: LibraryCoordinator
    @ObservedObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var toast: ToastManager
    @EnvironmentObject var sheetManager: SheetManager
    
    // MARK: - Player state
    
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
    
    // MARK: - Body
    
    var body: some View {
        TrackRowView(
            track: track,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            isHighlighted: isRevealed || isHighlighted,
            artwork: artwork,
            
            // Заголовок и артист теперь берём корректно
            title: metadata?.title ?? track.title,
            artist: metadata?.artist ?? track.artist ?? "",
            
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
            // Ленивая загрузка обложки
            if isScrollingFast || artwork != nil { return }
            
            try? await Task.sleep(nanoseconds: 60_000_000)
            
            let img = await ArtworkLoader.loadIfNeeded(
                current: artwork,
                trackId: track.id
            )
            if let img {
                await MainActor.run { artwork = img }
            }
            
            // Ленивая загрузка метаданных
            if metadata == nil {
                _ = await TrackMetadataCacheManager.shared.loadMetadata(for: track.url)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            
            // В ПЛЕЕР
            Button {
                Task {
                    let id = track.id

                    guard let resolved = await TrackRegistry.shared.resolvedURL(for: id) else {
                        print("❌ Нет resolvedURL для trackId \(id)")
                        return
                    }

                    let playerTrack = PlayerTrack(
                        id: id,
                        title: track.title,
                        artist: track.artist,
                        duration: track.duration,
                        fileName: resolved.lastPathComponent,
                        isAvailable: true
                    )

                    PlaylistManager.shared.tracks.append(playerTrack)
                    PlaylistManager.shared.saveToDisk()

                    toast.show(ToastData(
                        style: .track(
                            title: track.title ?? track.fileName,
                            artist: track.artist ?? ""
                        ),
                        artwork: track.artwork
                    ))
                }
            } label: {
                Label("В плеер", systemImage: "waveform")
            }
            .tint(.blue)
            
            
            // В ТРЕКЛИСТ
            Button {
                sheetManager.open(track: track)
            } label: {
                Label("В треклист", systemImage: "list.star")
            }
            .tint(.green)
            
            // ЕЩЁ
            Button {
                sheetManager.highlightedTrackID = track.id
                sheetManager.presentTrackActions(track: track, context: .library)
            } label: {
                Label("Ещё", systemImage: "ellipsis")
            }
            .tint(.gray)
        }
    }
}
