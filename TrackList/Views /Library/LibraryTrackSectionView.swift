//
//  LibraryTrackSectionView.swift
//  TrackList
//
//  Отображает секцию треков с заголовком по дате (например, "Сегодня").
//
//  Created by Pavel Fomin on 07.07.2025.
//

import SwiftUI

struct LibraryTrackSectionView: View {
    let title: String
    let tracks: [LibraryTrack]
    let allTracks: [LibraryTrack]
    let playerViewModel: PlayerViewModel
    @EnvironmentObject var toast: ToastManager

    var body: some View {
        Section(header: Text(title).font(.headline)) {
            ForEach(tracks, id: \.id) { track in
                LibraryTrackRow(
                    track: track,
                    allTracks: allTracks,
                    playerViewModel: playerViewModel
                )
            }
        }
    }

    
    // MARK: - Вынесенная строка трека для упрощения компиляции
    
    private struct LibraryTrackRow: View {
        let track: LibraryTrack
        let allTracks: [LibraryTrack]
        let playerViewModel: PlayerViewModel
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
                onSwipeLeft: {
                    // Добавляем трек в плеер
                    var imported = track.original
                    
                    // Сохраняем обложку
                    if let image = track.artwork {
                        let artworkId = UUID()
                        ArtworkManager.saveArtwork(image, id: artworkId)
                        imported.artworkId = artworkId
                    }

                    TrackListManager.shared.appendTrackToCurrentList(imported)
                    playerViewModel.trackListViewModel.loadTracks()

                    toast.show(ToastData(style: .track(title: track.title ?? track.fileName, artist: track.artist ?? ""), artwork: track.artwork))
                }
            )
        }
    }
}
