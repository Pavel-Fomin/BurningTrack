//
//  TrackRowView.swift
//  TrackList
//
//  Компонент UI для отображения одного трека в списке
//
//  Created by Pavel Fomin on 28.04.2025.
//

import SwiftUI
import Foundation

import SwiftUI
import Foundation

struct TrackRowView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    let track: any TrackDisplayable
    let onTap: () -> Void

    var isCurrent: Bool {
        playerViewModel.currentTrackDisplayable?.id == track.id
    }

    var isPlaying: Bool {
        isCurrent && playerViewModel.isPlaying
    }

    var body: some View {
        HStack(spacing: 12) {
            // MARK: - Обложка с иконкой поверх
            ZStack {
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

                if isCurrent {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 16, weight: .semibold))
                        .shadow(radius: 1)
                }
            }

            // MARK: - Текстовая информация
            let artist = track.artist?
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            let hasArtist = artist != nil && artist != "" && artist != "неизвестен"

            VStack(alignment: .leading, spacing: hasArtist ? 2 : 0) {
                if hasArtist, let artistText = track.artist {
                    Text(artistText)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                HStack {
                    Text(track.title ?? track.fileName)
                        .font(hasArtist ? .footnote : .subheadline)
                        .foregroundColor(hasArtist ? .secondary : .primary)
                        .lineLimit(1)

                    Spacer()

                    Text(formatTimeSmart(track.duration))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 0)
        .padding(.horizontal, 4)
        .opacity(track.isAvailable ? 1 : 0.4)
        .contentShape(Rectangle())
        .onTapGesture {
            if track.isAvailable {
                onTap()
            } else {
                print("❌ Трек недоступен: \(track.title ?? track.fileName)")
            }
        }
        .listRowBackground(
            isCurrent ? Color.accentColor.opacity(0.12) : Color.clear
        )
    }
}
