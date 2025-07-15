//
//  TrackRowView.swift
//  TrackList
//
//  Компонент UI для отображения трека в списке
//
//  Created by Pavel Fomin on 28.04.2025.
//

import SwiftUI
import Foundation

struct TrackRowView: View {
    let track: any TrackDisplayable
    let isCurrent: Bool
    let isPlaying: Bool
    let onTap: () -> Void
    var onSwipeLeft: (() -> Void)? = nil

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
            
            var hasArtist: Bool {
                guard let artist = track.artist?.trimmingCharacters(in: .whitespaces).lowercased() else { return false }
                return !artist.isEmpty && artist != "неизвестен"
            }

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
        
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let onSwipeLeft = onSwipeLeft {
                Button {
                    onSwipeLeft()
                } label: {
                    Label {
                        Text("Добавить в плеер")
                            .font(.caption)
                    } icon: {
                        EmptyView()
                    }
                }
                .tint(.accentColor)
            }
        }
        .listRowBackground(
            isCurrent ? Color.accentColor.opacity(0.12) : Color.clear
        )
    }
}
