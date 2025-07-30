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
        List(trackLists) { meta in
            Button {
                // Добавление трека в треклист
                let imported = track.original
                
                var list = TrackListManager.shared.getTrackListById(meta.id)
                list.tracks.append(imported)
                TrackListManager.shared.saveTracks(list.tracks, for: list.id)
                
                toast.show(ToastData(
                    style: .track(title: track.title ?? track.fileName, artist: track.artist ?? ""),
                    artwork: track.artwork
                ))
                
                onComplete()
            } label: {
                HStack {
                    Text(meta.name)
                        .lineLimit(1)
                    Spacer()
                    let trackCount = TrackListManager.shared.getTrackListById(meta.id).tracks.count
                            Text("\(trackCount) трек\(trackCount == 1 ? "" : trackCount % 10 == 1 && trackCount % 100 != 11 ? "" : trackCount % 10 >= 2 && trackCount % 10 <= 4 && !(trackCount % 100 >= 12 && trackCount % 100 <= 14) ? "а" : "ов")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Добавить в треклист")
        .navigationBarTitleDisplayMode(.inline)
    }
}
