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

struct TrackRowView: View {
    let track: Track               // Данные трека
    let isPlaying: Bool            // Идёт ли воспроизведение
    let isCurrent: Bool            // Является ли трек текущим
    let onTap: () -> Void          // Обработчик тапа

    var body: some View {
        HStack(spacing: 12) {
            // MARK: - Информация о треке
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title ?? track.fileName)
                    .font(.caption)
                    .foregroundColor(track.isAvailable ? .secondary : .gray)
                    .lineLimit(1)

                Text(track.title ?? track.fileName)
                    .font(.body)
                    .foregroundColor(track.isAvailable ? .primary : .gray)
                    .lineLimit(1)

                Text(formatTimeSmart(track.duration))
                    .font(.caption)
                    .foregroundColor(track.isAvailable ? .secondary : .gray)
            }

            Spacer()

            // MARK: - Иконка воспроизведения/паузы
            if isCurrent {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.body)
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            isCurrent
            ? Color.accentColor.opacity(0.12)
            : Color.clear
        )
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            if track.isAvailable {
                onTap()
            } else {
                print("Трек недоступен: \(track.title ?? track.fileName)")
            }
        }
    }
}
