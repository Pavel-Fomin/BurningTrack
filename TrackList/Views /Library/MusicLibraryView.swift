//
//  MusicLibraryView.swift
//  TrackList
//
//  Created by Pavel Fomin on 22.06.2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct MusicLibraryView: View {
    @StateObject private var manager = MusicLibraryManager.shared

    var body: some View {
        VStack(spacing: 16) {
            if manager.folderURL == nil {
                Spacer()
                Text("Папка фонотеки не выбрана")
                    .foregroundColor(.secondary)
                Spacer()
            } else if manager.tracks.isEmpty {
                Spacer()
                Text("Нет треков в выбранной папке")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List(manager.tracks, id: \.self) { trackURL in
                    Text(trackURL.lastPathComponent)
                }
            }
        }
        .onAppear {
            print("📺 MusicLibraryView: появилось. Треков: \(manager.tracks.count)")
        }
        .onReceive(manager.$tracks) { newTracks in
            print("📦 Обновился список треков: \(newTracks.count)")
        }
    }
}
