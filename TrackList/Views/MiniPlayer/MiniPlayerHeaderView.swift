//
//  MiniPlayerHeaderView.swift
//  TrackList
//
//  Верхняя часть мини-плеера.
//
//  Роль:
//  - отображает обложку и информацию о треке;
//  - содержит основные кнопки управления воспроизведением.
//
//  Created by Pavel Fomin on 08.02.2026.
//

import SwiftUI

struct MiniPlayerHeaderView: View {

    // MARK: - Input

    let artwork: UIImage?
    let title: String
    let artist: String
    let isPlaying: Bool
    /// Переопределение цвета заголовка для специальных состояний мини-плеера.
    let titleColorOverride: Color?

    let onPrevious: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void

    // MARK: - UI

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                artworkView

                VStack(alignment: .leading, spacing: 2) {
                    if !artist.isEmpty {
                        Text(artist)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Text(title)
                        .font(artist.isEmpty ? .caption : .caption2)
                        .foregroundColor(
                            titleColorOverride ?? (artist.isEmpty ? .primary : .secondary)
                        )
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                // Текст занимает только оставшееся место и не вытесняет кнопки.
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            MiniPlayerTransportControlsView(
                isPlaying: isPlaying,
                onPrevious: onPrevious,
                onPlayPause: onPlayPause,
                onNext: onNext
            )
            // Сохраняем ширину зон управления при сжатии текста.
            .layoutPriority(1)
        }
        .frame(minHeight: 40)
    }

    // MARK: - Artwork

    /// Показывает вращающуюся обложку текущего трека или статичную круглую заглушку.
    @ViewBuilder
    private var artworkView: some View {
        if let artwork {
            RotatingArtworkView(
                image: artwork,
                isActive: true,
                isPlaying: isPlaying,
                size: 40,
                rpm: 10
            )
            .frame(width: 40, height: 40)
        } else {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 40)
        }
    }
}
