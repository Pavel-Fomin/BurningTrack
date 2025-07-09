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
                playerViewModel: playerViewModel,
                track: track,
                onTap: {
                    if let current = playerViewModel.currentTrackDisplayable as? LibraryTrack, current.id == track.id {
                        playerViewModel.togglePlayPause()
                    } else {
                        playerViewModel.play(track: track, context: allTracks)
                    }
                },
                onSwipeLeft: {
                    let newTrack = Track(from: track)
                    if !playerViewModel.trackListViewModel.tracks.contains(where: { $0.id == newTrack.id }) {
                        playerViewModel.trackListViewModel.tracks.append(newTrack)
                    }

                    toast.show(
                        message: "Добавлено в плеер",
                        title: track.title,
                        artist: track.artist,
                        artwork: track.artwork
                    )
                    print("✅ Трек добавлен в плеер: \(track.title ?? track.fileName)")
                }
            )
        }
    }
}
