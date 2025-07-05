//
//  LibraryFolderView.swift
//  TrackList
//
//  Created by Pavel Fomin on 27.06.2025.
//

import SwiftUI

struct LibraryFolderView: View {
    let folder: LibraryFolder
    @ObservedObject var playerViewModel: PlayerViewModel

    @State private var loadedTracks: [Track] = []

    var body: some View {
        List {
            // Подпапки
            if !folder.subfolders.isEmpty {
                Section {
                    ForEach(folder.subfolders) { subfolder in
                        NavigationLink(destination: LibraryFolderView(folder: subfolder, playerViewModel: playerViewModel)) {
                            HStack(spacing: 12) {
                                Image(systemName: "folder")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                Text(subfolder.name)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            // Треки
            if !loadedTracks.isEmpty {
                ForEach(loadedTracks) { track in
                    TrackRowView(
                        track: track,
                        isPlaying: playerViewModel.isPlaying && playerViewModel.currentTrack?.id == track.id,
                        isCurrent: playerViewModel.currentTrack?.id == track.id,
                        onTap: {
                            if track.isAvailable {
                                if playerViewModel.currentTrack?.id == track.id {
                                    playerViewModel.togglePlayPause()
                                } else {
                                    playerViewModel.play(track: track)
                                }
                            } else {
                                print("❌ Трек недоступен: \(track.title ?? track.fileName)")
                            }
                        }
                    )
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle(folder.name)
        .task {
            await loadTracksIfNeeded()
        }
    }

    // MARK: - Загрузка треков
    private func loadTracksIfNeeded() async {
        guard loadedTracks.isEmpty else { return }

        var result: [Track] = []

        for url in folder.audioFiles {
            do {
                let track = try await Track.load(from: url)
                result.append(track)
            } catch {
                print("⚠️ Не удалось загрузить \(url.lastPathComponent): \(error)")
            }
        }

        await MainActor.run {
            loadedTracks = result
        }
    }
}
