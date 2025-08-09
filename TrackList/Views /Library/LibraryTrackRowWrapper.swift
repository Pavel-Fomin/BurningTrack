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
    let isScrollingFast: Bool
    
    @State private var artwork: CGImage? = nil
    
    @ObservedObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var toast: ToastManager
    @EnvironmentObject var sheetManager: SheetManager

    var body: some View {
        let isCurrent = playerViewModel.isCurrent(track, in: .library)
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
                if playerViewModel.isCurrent(track, in: .library) {
                    playerViewModel.togglePlayPause()
                } else {
                    playerViewModel.play(track: track, context: allTracks)

                }
            },
            trackListNames: trackListNames
        )
        
        // Ленивая загрузка обложки, только если ещё не загружена
        .task(id: track.url) {
            if isScrollingFast { return } // при «полёте» не грузим

            // грузим вне main, потом обновляем стейт на main
            let img = await Task.detached(priority: .utility) {
                await ArtworkLoader.loadIfNeeded(current: artwork, url: track.url)
            }.value
            if let img { await MainActor.run { artwork = img } }

            // теги подтягиваем, если их нет (чтобы не зависеть от VM-префетча)
            if metadata == nil {
                _ = await TrackMetadataCacheManager.shared.loadMetadata(for: track.url)
                // UI сам подхватит из кэша через твои биндинги/перерисовку
            }
        }
        
        
        .onChange(of: isScrollingFast) { _, nowFast in
            guard nowFast == false else { return }  // закончился «полёт» — догружаем
            Task {
                let img = await Task.detached(priority: .utility) {
                    await ArtworkLoader.loadIfNeeded(current: artwork, url: track.url)
                }.value
                if let img { await MainActor.run { artwork = img } }

                if metadata == nil {
                    _ = await TrackMetadataCacheManager.shared.loadMetadata(for: track.url)
                }
            }
        }
        
        // .onDisappear {
        //     // отменяем/чистим, если есть поддержка отмены в лоадере
        //     // ArtworkLoader.cancelLoad(for: track.url)
        // }
        
        
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
        }
    }
}
