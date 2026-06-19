//
//  PlayerPlaybackContextStore.swift
//  TrackList
//
//  Хранилище текущего контекста воспроизведения.
//
//  Created by Pavel Fomin on 19.06.2026.
//

import Foundation

/// Хранит текущий контекст воспроизведения.
/// Отвечает только за:
/// - сохранение контекста player / tracklist / library;
/// - очистку неактивных контекстов;
/// - поиск следующего и предыдущего трека.
@MainActor
final class PlayerPlaybackContextStore {

    private var playerTracksContext: [PlayerTrack] = []
    private var trackListContext: [Track] = []
    private var libraryTracksContext: [LibraryTrack] = []

    /// Позволяет создавать store как зависимость по умолчанию в init PlayerViewModel.
    nonisolated init() {}

    /// Обновляет контекст воспроизведения под тип текущего трека.
    func updateContext(
        currentTrack: any TrackDisplayable,
        context: [any TrackDisplayable]
    ) {
        if currentTrack is PlayerTrack {
            playerTracksContext = context.compactMap { $0 as? PlayerTrack }
            trackListContext = []
            libraryTracksContext = []
        } else if currentTrack is Track {
            trackListContext = context.compactMap { $0 as? Track }
            playerTracksContext = []
            libraryTracksContext = []
        } else if currentTrack is LibraryTrack {
            libraryTracksContext = context.compactMap { $0 as? LibraryTrack }
            trackListContext = []
            playerTracksContext = []
        } else {
            clear()
        }
    }

    /// Возвращает следующий трек в текущем контексте.
    func nextTrack(after currentTrack: any TrackDisplayable) -> (track: any TrackDisplayable, context: [any TrackDisplayable])? {
        if let libraryTrack = currentTrack as? LibraryTrack {
            guard let index = libraryTracksContext.firstIndex(where: { $0.id == libraryTrack.id }),
                  index + 1 < libraryTracksContext.count else { return nil }

            return (
                libraryTracksContext[index + 1],
                libraryTracksContext.map { $0 as any TrackDisplayable }
            )
        }

        if let track = currentTrack as? Track {
            guard let index = trackListContext.firstIndex(where: { $0.id == track.id }),
                  index + 1 < trackListContext.count else { return nil }

            return (
                trackListContext[index + 1],
                trackListContext.map { $0 as any TrackDisplayable }
            )
        }

        if let playerTrack = currentTrack as? PlayerTrack {
            guard let index = playerTracksContext.firstIndex(where: { $0.id == playerTrack.id }),
                  index + 1 < playerTracksContext.count else { return nil }

            return (
                playerTracksContext[index + 1],
                playerTracksContext.map { $0 as any TrackDisplayable }
            )
        }

        return nil
    }

    /// Возвращает предыдущий трек в текущем контексте.
    func previousTrack(before currentTrack: any TrackDisplayable) -> (track: any TrackDisplayable, context: [any TrackDisplayable])? {
        if let libraryTrack = currentTrack as? LibraryTrack {
            guard let index = libraryTracksContext.firstIndex(where: { $0.id == libraryTrack.id }),
                  index - 1 >= 0 else { return nil }

            return (
                libraryTracksContext[index - 1],
                libraryTracksContext.map { $0 as any TrackDisplayable }
            )
        }

        if let track = currentTrack as? Track {
            guard let index = trackListContext.firstIndex(where: { $0.id == track.id }),
                  index - 1 >= 0 else { return nil }

            return (
                trackListContext[index - 1],
                trackListContext.map { $0 as any TrackDisplayable }
            )
        }

        if let playerTrack = currentTrack as? PlayerTrack {
            guard let index = playerTracksContext.firstIndex(where: { $0.id == playerTrack.id }),
                  index - 1 >= 0 else { return nil }

            return (
                playerTracksContext[index - 1],
                playerTracksContext.map { $0 as any TrackDisplayable }
            )
        }

        return nil
    }

    /// Очищает все контексты.
    func clear() {
        playerTracksContext = []
        trackListContext = []
        libraryTracksContext = []
    }

    /// Возвращает все известные trackId из текущих контекстов.
    func allTrackIds(currentTrack: (any TrackDisplayable)?) -> Set<UUID> {
        var ids = Set<UUID>()

        if let currentTrack {
            ids.insert(currentTrack.trackId)
        }

        for track in playerTracksContext {
            ids.insert(track.trackId)
        }

        for track in trackListContext {
            ids.insert(track.trackId)
        }

        for track in libraryTracksContext {
            ids.insert(track.trackId)
        }

        return ids
    }
}
