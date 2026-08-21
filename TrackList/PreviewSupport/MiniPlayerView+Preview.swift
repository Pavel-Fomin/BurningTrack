//
//  MiniPlayerView+Preview.swift
//  TrackList
//
//  Xcode Preview для чистого MiniPlayerScreenState.
//
//  Created by Pavel Fomin on 13.06.2026.
//

#if DEBUG
import SwiftUI

/// Строит изолированный MiniPlayer из готовых presentation-данных без production-зависимостей.
@MainActor
private func makeMiniPlayerPreview(
    state: MiniPlayerScreenState
) -> some View {
    MiniPlayerView(
        state: state,
        onAction: { _ in }
    )
    .padding()
}

/// Готовые состояния позволяют проверить разметку без реального PlayerManager, настроек и навигации.
@MainActor
private enum MiniPlayerPreviewStates {

    static let empty = MiniPlayerScreenState(
        artworkRequest: nil,
        title: "Nothing Playing",
        artist: "",
        currentTime: 0,
        duration: 0,
        isPlaying: false,
        isPlaybackEnabled: false,
        isFavorite: false,
        isFavoriteEnabled: false,
        waveformState: .unavailable,
        canShowCurrentTrackInLibrary: false,
        isShuffleEnabled: false,
        isRepeatAllEnabled: false,
        isRepeatOneEnabled: false,
        initialIsExpanded: false
    )

    static let playing = MiniPlayerScreenState(
        artworkRequest: nil,
        title: "Midnight Drive",
        artist: "Neon Coast",
        currentTime: 96,
        duration: 248,
        isPlaying: true,
        isPlaybackEnabled: true,
        isFavorite: true,
        isFavoriteEnabled: true,
        waveformState: .ready([0.15, 0.38, 0.72, 0.44, 0.91]),
        canShowCurrentTrackInLibrary: true,
        isShuffleEnabled: true,
        isRepeatAllEnabled: false,
        isRepeatOneEnabled: false,
        initialIsExpanded: true
    )

    static let paused = MiniPlayerScreenState(
        artworkRequest: nil,
        title: "Midnight Drive",
        artist: "Neon Coast",
        currentTime: 96,
        duration: 248,
        isPlaying: false,
        isPlaybackEnabled: true,
        isFavorite: false,
        isFavoriteEnabled: true,
        waveformState: .ready([0.15, 0.38, 0.72, 0.44, 0.91]),
        canShowCurrentTrackInLibrary: true,
        isShuffleEnabled: false,
        isRepeatAllEnabled: true,
        isRepeatOneEnabled: false,
        initialIsExpanded: false
    )

    static let loading = MiniPlayerScreenState(
        artworkRequest: nil,
        title: "Loading Track",
        artist: "",
        currentTime: 0,
        duration: 0,
        isPlaying: false,
        isPlaybackEnabled: false,
        isFavorite: false,
        isFavoriteEnabled: false,
        waveformState: .loading,
        canShowCurrentTrackInLibrary: false,
        isShuffleEnabled: false,
        isRepeatAllEnabled: false,
        isRepeatOneEnabled: false,
        initialIsExpanded: false
    )
}

#Preview("Пустой мини-плеер") {
    makeMiniPlayerPreview(state: MiniPlayerPreviewStates.empty)
}

#Preview("Воспроизведение") {
    makeMiniPlayerPreview(state: MiniPlayerPreviewStates.playing)
}

#Preview("Пауза") {
    makeMiniPlayerPreview(state: MiniPlayerPreviewStates.paused)
}

#Preview("Загрузка") {
    makeMiniPlayerPreview(state: MiniPlayerPreviewStates.loading)
}
#endif
