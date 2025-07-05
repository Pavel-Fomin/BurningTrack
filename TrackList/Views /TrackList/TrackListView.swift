//
//  TrackListView.swift
//  TrackList
//
//  Основная вью для отображения списка треков внутри выбранного треклиста
//  Отвечает за вывод строк треков, их удаление, перемещение, а также
//  визуальное выделение текущего трека в плеере.
//
//  Created by Pavel Fomin on 29.04.2025.
//

import SwiftUI
import AVFoundation

struct TrackListView: View {
    @ObservedObject var trackListViewModel: TrackListViewModel
    @ObservedObject var playerViewModel: PlayerViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        List {
            
            // MARK: - Счётчик треков
            Section {
                Text("\(trackListViewModel.tracks.count) треков · \(trackListViewModel.formattedTotalDuration)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }

            // MARK: - Список треков
            ForEach(trackListViewModel.tracks) { track in
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
                .padding(.vertical, 4)
            }
            .onDelete { indexSet in
                trackListViewModel.removeTrack(at: indexSet)
            }
            .onMove { indices, newOffset in
                trackListViewModel.moveTrack(from: indices, to: newOffset)
            }
        }
        .onAppear {
            // Проверка доступности треков при отображении
            trackListViewModel.refreshTrackAvailability()
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

}
