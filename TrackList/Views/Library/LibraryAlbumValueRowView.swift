//
//  LibraryAlbumValueRowView.swift
//  TrackList
//
//  Строка альбома в списке значений музыкальной коллекции.
//
//  Created by Pavel Fomin on 10.07.2026.
//

import SwiftUI

struct LibraryAlbumValueRowView: View {
    // MARK: - Входные данные

    /// Значение альбома с данными, собранными из SQLite metadata.
    let value: LibraryCollectionValue
    /// Запрос обложки representative track, если runtime snapshot уже загружен.
    let artworkRequest: ArtworkRequest?
    /// Показывает, что текущий трек плеера входит в этот альбом.
    let isCurrent: Bool
    /// Показывает, что текущий трек альбома сейчас воспроизводится.
    let isPlaying: Bool

    // MARK: - UI

    var body: some View {
        HStack(spacing: 12) {
            artworkView

            titleColumn

            Spacer(minLength: 12)

            yearView
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    /// Левая квадратная зона обложки или системной заглушки.
    private var artworkView: some View {
        ZStack {
            ArtworkPreparationView(request: artworkRequest) { image in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                placeholderArtworkView
            }

            if isCurrent {
                ActiveArtworkOverlayView(isPlaying: isPlaying)
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 0.5)
        }
    }

    /// Заглушка альбома без временных mock-обложек.
    private var placeholderArtworkView: some View {
        ZStack {
            Circle()
                .fill(Color.secondary.opacity(0.18))

            Image(systemName: "square.stack.fill")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Color.secondary.opacity(0.7))
        }
    }

    /// Центральная колонка с названием альбома и артистом.
    private var titleColumn: some View {
        VStack(alignment: .leading, spacing: value.artist == nil ? 0 : 2) {
            Text(value.title)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(1)

            if let artist = value.artist {
                Text(artist)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Правая колонка показывает только год альбома, без счётчика треков.
    @ViewBuilder
    private var yearView: some View {
        if let year = value.year {
            Text(String(year))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .monospacedDigit()
        }
    }
}
