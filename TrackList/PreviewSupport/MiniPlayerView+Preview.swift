//
//  MiniPlayerView+Preview.swift
//  TrackList
//
//  Xcode Preview для мини-плеера.
//
//  Created by Pavel Fomin on 13.06.2026.
//

#if DEBUG
import SwiftUI

/// Создаёт изолированный заголовок мини-плеера без PlayerViewModel и его тяжёлых зависимостей.
private func makeMiniPlayerHeaderPreview(
    isFavorite: Bool,
    isFavoriteEnabled: Bool,
    title: String,
    artist: String
) -> some View {
    MiniPlayerHeaderView(
        artworkRequest: nil,
        title: title,
        artist: artist,
        isPlaying: false,
        isFavorite: isFavorite,
        isFavoriteEnabled: isFavoriteEnabled,
        titleColorOverride: isFavoriteEnabled ? nil : .secondary,
        onContentTap: {},
        onContentSwipePrevious: {},
        onContentSwipeNext: {},
        onFavorite: {}
    )
    .padding()
}

#Preview("Трек не в Избранном") {
    makeMiniPlayerHeaderPreview(
        isFavorite: false,
        isFavoriteEnabled: true,
        title: "Midnight Drive",
        artist: "Neon Coast"
    )
}

#Preview("Трек в Избранном") {
    makeMiniPlayerHeaderPreview(
        isFavorite: true,
        isFavoriteEnabled: true,
        title: "Midnight Drive",
        artist: "Neon Coast"
    )
}

#Preview("Пустой мини-плеер") {
    makeMiniPlayerHeaderPreview(
        isFavorite: false,
        isFavoriteEnabled: false,
        title: "Nothing Playing",
        artist: ""
    )
}
#endif
