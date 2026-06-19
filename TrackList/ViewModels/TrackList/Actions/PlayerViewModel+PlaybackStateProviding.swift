//
//  PlayerViewModel+PlaybackStateProviding.swift
//  TrackList
//
//  Created by Pavel Fomin on 19.06.2026.
//

import Combine
import Foundation

extension PlayerViewModel: PlaybackStateProviding {

    /// Текущий снимок playback-состояния для detail-flow одного треклиста.
    var playbackState: PlaybackState {
        PlaybackState(
            currentDisplayableId: currentTrackDisplayable?.id,
            currentContext: currentContext,
            isPlaying: isPlaying
        )
    }

    /// Публикует изменения playback-состояния без создания второго хранилища.
    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> {
        Publishers.CombineLatest3(
            $currentTrackDisplayable,
            $currentContext,
            $isPlaying
        )
        .map { currentTrackDisplayable, currentContext, isPlaying in
            PlaybackState(
                currentDisplayableId: currentTrackDisplayable?.id,
                currentContext: currentContext,
                isPlaying: isPlaying
            )
        }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
}
