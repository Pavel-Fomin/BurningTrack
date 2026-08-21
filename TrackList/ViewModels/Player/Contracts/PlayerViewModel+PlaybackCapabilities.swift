//
//  PlayerViewModel+PlaybackCapabilities.swift
//  TrackList
//
//  Реализация внешних playback capability PlayerViewModel.
//
//  Created by Pavel Fomin on 02.08.2026.
//

import Combine
import Foundation

extension PlayerViewModel: PlaybackStateProviding, TrackPlaybackControlling, CurrentPlaybackFileReleasing {

    /// Актуальный снимок playback-состояния без создания второго источника состояния.
    var playbackState: PlaybackStateSnapshot {
        PlaybackStateSnapshot(
            currentDisplayableId: currentTrackDisplayable?.id,
            currentTrackId: currentTrackDisplayable?.trackId,
            currentContext: currentContext,
            currentContextSource: currentPlaybackContextSource,
            isPlaying: isPlaying,
            activeTrackChangeReason: activeTrackChangeReason,
            automaticListScrollTrigger: automaticListScrollTrigger
        )
    }

    /// Идентификатор текущего отображаемого элемента для строк очереди и треклистов.
    var currentDisplayableId: UUID? {
        currentTrackDisplayable?.id
    }

    /// Идентификатор физического трека для feature, работающих с локальным файлом.
    var currentTrackId: UUID? {
        currentTrackDisplayable?.trackId
    }

    /// Постоянный источник контекста, сохранённый PlayerViewModel для восстановления playback-порядка.
    var currentContextSource: PlaybackContextSource? {
        currentTrackDisplayable == nil ? nil : currentPlaybackContextSource
    }

    /// Публикует единый снимок без отдельного хранилища и несогласованных подписок.
    var playbackStatePublisher: AnyPublisher<PlaybackStateSnapshot, Never> {
        Publishers.CombineLatest4(
            $currentTrackDisplayable,
            $currentContext,
            $isPlaying,
            $currentPlaybackContextSource
        )
        .combineLatest(
            $activeTrackChangeReason.combineLatest($automaticListScrollTrigger)
        )
        .map { playbackState, scrollState in
            let (
                currentTrackDisplayable,
                currentContext,
                isPlaying,
                currentContextSource
            ) = playbackState
            let (activeTrackChangeReason, automaticListScrollTrigger) = scrollState

            return PlaybackStateSnapshot(
                currentDisplayableId: currentTrackDisplayable?.id,
                currentTrackId: currentTrackDisplayable?.trackId,
                currentContext: currentContext,
                currentContextSource: currentTrackDisplayable == nil ? nil : currentContextSource,
                isPlaying: isPlaying,
                activeTrackChangeReason: activeTrackChangeReason,
                automaticListScrollTrigger: automaticListScrollTrigger
            )
        }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

}
