//
//  MiniPlayerPresenter.swift
//  TrackList
//
//  Преобразует playback-данные в готовое состояние MiniPlayer.
//
//  Created by Pavel Fomin on 10.08.2026.
//

import Foundation

/// Формирует готовый ScreenState MiniPlayer без команд, singleton-зависимостей и асинхронной работы.
struct MiniPlayerPresenter {

    /// Преобразует каноничное состояние Player в данные, готовые для разметки MiniPlayer.
    func present(
        miniPlayerState: MiniPlayerState,
        waveformState: PlayerWaveformState,
        isCurrentTrackFavorite: Bool,
        playbackMode: PlaybackMode,
        currentTrackDisplayable: (any TrackDisplayable)?,
        initialIsExpanded: Bool
    ) -> MiniPlayerScreenState {
        let isPlaybackEnabled = currentTrackDisplayable != nil

        let content = content(for: miniPlayerState)
        return MiniPlayerScreenState(
            artworkRequest: content.artworkRequest,
            title: content.title,
            artist: content.artist,
            currentTime: content.currentTime,
            duration: content.duration,
            isPlaying: content.isPlaying,
            isPlaybackEnabled: isPlaybackEnabled,
            isFavorite: isCurrentTrackFavorite,
            isFavoriteEnabled: isPlaybackEnabled,
            waveformState: waveformState,
            canShowCurrentTrackInLibrary: MiniPlayerActionAvailability.canShowInLibrary(
                miniPlayerState: miniPlayerState,
                track: currentTrackDisplayable
            ),
            isShuffleEnabled: playbackMode.isShuffleEnabled,
            isRepeatAllEnabled: playbackMode.repeatMode == .all,
            isRepeatOneEnabled: playbackMode.repeatMode == .one,
            initialIsExpanded: initialIsExpanded
        )
    }

    /// Выделяет presentation-правила основного содержимого из SwiftUI View.
    private func content(for state: MiniPlayerState) -> Content {
        switch state {
        case .empty:
            return Content(
                artworkRequest: nil,
                title: String(localized: "Nothing Playing"),
                artist: "",
                currentTime: 0,
                duration: 0,
                isPlaying: false
            )

        case let .playing(staticState, progressState),
             let .paused(staticState, progressState):
            return Content(
                artworkRequest: staticState.artworkRequest,
                title: staticState.title,
                artist: PlayerPresentationText.miniPlayerArtist(for: staticState.artist),
                currentTime: progressState.currentTime,
                duration: progressState.duration,
                isPlaying: progressState.isPlaying
            )

        case let .loading(staticState):
            return Content(
                artworkRequest: staticState?.artworkRequest,
                title: staticState?.title ?? String(localized: "Loading Track"),
                artist: staticState.map {
                    PlayerPresentationText.miniPlayerArtist(for: $0.artist)
                } ?? "",
                currentTime: 0,
                duration: 0,
                isPlaying: false
            )

        case .error:
            return Content(
                artworkRequest: nil,
                title: String(localized: "Playback Error"),
                artist: "",
                currentTime: 0,
                duration: 0,
                isPlaying: false
            )
        }
    }

    /// Промежуточный тип не покидает presenter и не становится вторым публичным состоянием feature.
    private struct Content {
        let artworkRequest: ArtworkRequest?
        let title: String
        let artist: String
        let currentTime: TimeInterval
        let duration: TimeInterval
        let isPlaying: Bool
    }
}

/// Единое чистое правило доступности общего сценария «Показать в фонотеке».
enum MiniPlayerActionAvailability {

    /// Не предлагает переход без текущего трека и повторно использует типизированные правила player menu.
    static func canShowInLibrary(
        miniPlayerState: MiniPlayerState,
        track: (any TrackDisplayable)?
    ) -> Bool {
        switch miniPlayerState {
        case .empty, .error:
            return false
        case .loading, .playing, .paused:
            break
        }

        guard let track else {
            return false
        }

        switch track {
        case is LibraryTrack:
            return true
        case let sourceTrack as any PurchasedITunesTrackRepresentable:
            return TrackMenuActionAvailability.isAvailable(
                .showInLibrary,
                source: sourceTrack.source,
                context: .player
            )
        default:
            return false
        }
    }
}
