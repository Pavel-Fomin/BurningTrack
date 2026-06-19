//
//  PlaybackState.swift
//  TrackList
//
//  Created by Pavel Fomin on 19.06.2026.
//

import Foundation

/// Снимок playback-состояния, нужный detail-flow одного треклиста.
struct PlaybackState: Equatable {

    /// Идентификатор текущего TrackDisplayable.
    /// Для треклиста это id строки, поэтому он сравнивается с TrackListRowState.id.
    let currentDisplayableId: UUID?

    /// Контекст текущего воспроизведения.
    let currentContext: PlaybackContext?

    /// Идёт ли воспроизведение.
    let isPlaying: Bool
}
