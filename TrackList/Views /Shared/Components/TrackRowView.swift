//
//  TrackRowView.swift
//  TrackList
//
//  Компонент UI для отображения трека в списке
//
//  Created by Pavel Fomin on 28.04.2025.
//

import SwiftUI
import UIKit

struct TrackRowView: View {

    // MARK: - Входные параметры

    let track: any TrackDisplayable
    let isCurrent: Bool
    let isPlaying: Bool
    let isHighlighted: Bool
    let artwork: UIImage?
    let title: String?
    let artist: String?
    let duration: Double?
    let onRowTap: () -> Void        /// Тап по правой части строки (воспроизведение / пауза)
    let onArtworkTap: (() -> Void)? /// Тап по обложке (например, открытие экрана "О треке")

    var trackListNames: [String]? = nil
    var useNativeSwipeActions: Bool = false

    // MARK: - UI

    var body: some View {
        HStack(spacing: 12) {

            // Левая зона — обложка
            artworkView
                .contentShape(Rectangle())
                .onTapGesture {
                    guard track.isAvailable else {
                        print("❌ Трек недоступен: \(track.title ?? track.fileName)")
                        return
                    }

                    // Если обработчик не передан — ничего не делаем
                    onArtworkTap?()
                }

            // Правая зона — информация о треке
            trackInfoView
                .contentShape(Rectangle())
                .onTapGesture {
                    guard track.isAvailable else {
                        print("❌ Трек недоступен: \(track.title ?? track.fileName)")
                        return
                    }

                    onRowTap()
                }
        }
        .padding(.vertical, 0)
        .padding(.horizontal, 4)
        .opacity(track.isAvailable ? 1 : 0.4)
        .listRowBackground(rowHighlightColor)
    }

    // MARK: - Обложка

    private var artworkView: some View {
        ZStack {
            if let artwork {
                RotatingArtworkView(
                    image: artwork,
                    isActive: isCurrent,
                    isPlaying: isPlaying,
                    size: 48,
                    rpm: 10
                )
                .frame(width: 48, height: 48)

            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 48, height: 48)

                if isCurrent {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 16, weight: .semibold))
                        .shadow(radius: 1)
                }
            }
        }
    }

    // MARK: - Информация о треке

    private var trackInfoView: some View {
        let hasArtist: Bool = {
            guard let artist = artist?.trimmingCharacters(in: .whitespaces).lowercased() else { return false }
            return !artist.isEmpty && artist != "неизвестен"
        }()

        return VStack(alignment: .leading, spacing: hasArtist ? 2 : 0) {
            if hasArtist, let artistText = artist {
                Text(artistText)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            HStack {
                Text(title ?? track.fileName)
                    .font(hasArtist ? .footnote : .subheadline)
                    .foregroundColor(hasArtist ? .secondary : .primary)
                    .lineLimit(1)

                Spacer()

                Text(formatTimeSmart(duration ?? track.duration))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            if let trackListNames, !trackListNames.isEmpty {
                Text("уже в: \(trackListNames.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Подсветка строки

    private var rowHighlightColor: Color {
        if isHighlighted {
            return Color.gray.opacity(0.12)          // Подсветка при открытом шите
        } else if isCurrent {
            return Color.accentColor.opacity(0.12)   // Подсветка текущего трека
        } else {
            return Color.clear
        }
    }
}
