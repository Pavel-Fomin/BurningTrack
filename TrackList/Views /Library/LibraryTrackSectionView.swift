//
//  LibraryTrackSectionView.swift
//  TrackList
//
//  Отображает секцию треков с разделителем
//
//  Created by Pavel Fomin on 07.07.2025.
//

import SwiftUI

struct LibraryTrackSectionView: View {
    let title: String
    let tracks: [LibraryTrack]
    let allTracks: [LibraryTrack]
    let playerViewModel: PlayerViewModel
    let trackListViewModel: TrackListViewModel
    @EnvironmentObject var toast: ToastManager
    
    var body: some View {
        Section(header: Text(title).font(.headline)) {
            ForEach(tracks, id: \.id) { track in
                LibraryTrackRow(
                    track: track,
                    allTracks: allTracks,
                    playerViewModel: playerViewModel,
                    trackListViewModel: trackListViewModel
                )
            }
        }
    }
    
    
    // MARK: - Вынесенная строка трека для упрощения компиляции
    
    private struct LibraryTrackRow: View {
        let track: LibraryTrack
        let allTracks: [LibraryTrack]
        let playerViewModel: PlayerViewModel
        let trackListViewModel: TrackListViewModel
        @EnvironmentObject var toast: ToastManager
        
        var body: some View {
            TrackRowView(
                track: track,
                isCurrent: track.id == playerViewModel.currentTrackDisplayable?.id,
                isPlaying: playerViewModel.isPlaying && track.id == playerViewModel.currentTrackDisplayable?.id,
                onTap: {
                    if let current = playerViewModel.currentTrackDisplayable as? LibraryTrack, current.id == track.id {
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
                            
                            // Добавляем трек в PlaylistManager
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
                            
                            // Показываем тост
                            toast.show(ToastData(
                                style: .track(title: track.title ?? track.fileName, artist: track.artist ?? ""),
                                artwork: track.artwork
                            ))
                        },
                        labelType: .textOnly
                    )
                ]
            )
        }
    }
}
