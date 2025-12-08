//
//  AddToTrackListSheet.swift
//  TrackList
//
//  Добавить в треклист
//
//  Created by Pavel Fomin on 29.07.2025.
//

import Foundation
import SwiftUI

struct AddToTrackListSheet: View {
    let track: any TrackDisplayable
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var toast: ToastManager
    
    private let trackLists = TrackListsManager.shared.loadTrackListMetas()
    
    var body: some View {
        List(trackLists) { meta in
            Button {
                Task {
                    // 1) Резолвим URL только через BookmarksRegistry + BookmarkResolver
                    guard let url = await BookmarkResolver.url(forTrack: track.id) else {
                        print("❌ BookmarkResolver: нет URL для трека \(track.id)")
                        return
                    }

                    // 2) Собираем Track
                    let imported = Track(
                        id: track.id,
                        title: track.title,
                        artist: track.artist,
                        duration: track.duration,
                        fileName: url.lastPathComponent,
                        isAvailable: true
                    )

                    // 3) Работа с треклистом
                    var list = TrackListManager.shared.getTrackListById(meta.id)
                    list.tracks.append(imported)
                    TrackListManager.shared.saveTracks(list.tracks, for: list.id)

                    // 4) UI
                    await MainActor.run {
                        toast.show(
                            ToastData(
                                style: .track(
                                    title: track.title ?? track.fileName,
                                    artist: track.artist ?? ""
                                ),
                                artwork: track.artwork
                            )
                        )
                        onComplete()
                    }
                }
            } label: {
                HStack {
                    Text(meta.name)
                        .lineLimit(1)
                    Spacer()
                    let count = TrackListManager.shared.getTrackListById(meta.id).tracks.count
                    Text("\(count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .listRowBackground(Color(.tertiarySystemBackground))
        }
        .navigationTitle("Добавить в треклист")
        .navigationBarTitleDisplayMode(.inline)
    }
}
