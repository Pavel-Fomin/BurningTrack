//
//  LibraryTrackRow.swift
//  TrackList
//
//  Created by Pavel Fomin on 05.07.2025.
//

import SwiftUI

struct LibraryTrackRow: View {
    let track: LibraryTrack
    let isCurrent: Bool
    let isPlaying: Bool
    let onTap: () -> Void
    @EnvironmentObject var toast: ToastManager

    var body: some View {
        TrackRowView(
            track: track,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            onTap: onTap,
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
            ]
        )
    }
}
