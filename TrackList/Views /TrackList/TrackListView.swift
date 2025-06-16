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
                trackRow(for: track)
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

    // MARK: - Строка трека (ячейка в списке)

    private func trackRow(for track: Track) -> some View {
        HStack(spacing: 12) {
            // Обложка трека или серый placeholder
            if let image = track.artwork {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .cornerRadius(6)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .cornerRadius(6)
            }

            // Информация о треке: артист, название, длительность
            VStack(alignment: .leading, spacing: 4) {
                Text(track.artist ?? "Неизвестный артист")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack {
                    Text(track.title ?? track.fileName)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Text(formatTimeSmart(track.duration))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .opacity(track.isAvailable ? 1 : 0.4) // Приглушение недоступных треков
        .padding(.vertical, 4)
        .listRowBackground(
            playerViewModel.currentTrack?.id == track.id
            ? (colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.12))
            : Color.clear
        )
        .onTapGesture {
            // Тап по строке: воспроизведение или пауза
            if track.isAvailable {
                if playerViewModel.currentTrack?.id == track.id {
                    playerViewModel.togglePlayPause()
                } else {
                    playerViewModel.play(track: track)
                }
            } else {
                print("Трек недоступен: \(track.title ?? track.fileName)")
            }
        }
    }
}
