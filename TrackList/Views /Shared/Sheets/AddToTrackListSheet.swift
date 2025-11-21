//
//  AddToTrackListSheet.swift
//  TrackList
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
                Task { @MainActor in
                    // Загружаем URL через TrackRegistry
                    guard let url = await TrackRegistry.shared.resolvedURL(for: track.id) else {
                        print("❌ URL не найден в TrackRegistry для \(track.id)")
                        return
                    }

                    // Собираем Track из TrackDisplayable
                    let imported = Track(
                        id: track.id,
                        title: track.title,
                        artist: track.artist,
                        duration: track.duration,
                        fileName: url.lastPathComponent,
                        isAvailable: true     // доступность проверится позже в refresh
                    )
                    
                    // Загружаем список → дополняем → сохраняем
                    var list = TrackListManager.shared.getTrackListById(meta.id)
                    list.tracks.append(imported)
                    TrackListManager.shared.saveTracks(list.tracks, for: list.id)
                    
                    // Тост
                    toast.show(ToastData(
                        style: .track(title: track.title ?? track.fileName, artist: track.artist ?? ""),
                        artwork: track.artwork
                    ))
                    
                    onComplete()
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
        }
        .navigationTitle("Добавить в треклист")
        .navigationBarTitleDisplayMode(.inline)
    }
}
