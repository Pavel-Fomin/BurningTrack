//
//  AddToTrackListSheet.swift
//  TrackList
//
//  Created by Pavel Fomin on 29.07.2025.
//

import Foundation
import SwiftUI

struct AddToTrackListSheet: View {
    let track: LibraryTrack
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var toast: ToastManager
    
    private let trackLists = TrackListManager.shared.loadTrackListMetas()
    
    var body: some View {
        
        // Здесь размещай содержимое sheet'а
        List(trackLists) { meta in
            Button(meta.name) {
                
                // Добавление трека в треклист
                var imported = track.original

                if let image = track.artwork {
                    let artworkId = UUID()
                    ArtworkManager.saveArtwork(image, id: artworkId)
                    imported.artworkId = artworkId
                }

                var list = TrackListManager.shared.getTrackListById(meta.id)
                list.tracks.append(imported)
                TrackListManager.shared.saveTracks(list.tracks, for: list.id)
                toast.show(ToastData(
                    style: .track(title: track.title ?? track.fileName, artist: track.artist ?? ""),
                    artwork: track.artwork
                ))

                onComplete()
            }
        }
        .navigationTitle("Добавить в треклист")
        .navigationBarTitleDisplayMode(.inline)
        .padding(.top, -28)
    }
}
