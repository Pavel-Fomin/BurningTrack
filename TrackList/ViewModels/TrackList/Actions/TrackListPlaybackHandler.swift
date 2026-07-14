//
//  TrackListPlaybackHandler.swift
//  TrackList
//
//  Created by Pavel Fomin on 17.06.2026.
//

import Foundation

/// Обрабатывает playback-действия detail-flow одного треклиста.
/// Отвечает только за запуск, паузу и продолжение воспроизведения.
@MainActor
final class TrackListPlaybackHandler {

    /// Источник read-only данных одного треклиста.
    private let reader: any TrackListReading

    /// Управляет playback-командами треклиста.
    private let playbackManager: any TrackListPlaybackManaging

    /// Создаёт обработчик playback-действий одного треклиста.
    init(
        reader: any TrackListReading,
        playbackManager: any TrackListPlaybackManaging
    ) {
        self.reader = reader
        self.playbackManager = playbackManager
    }

    /// Обрабатывает нажатие на строку трека.
    func handleRowTap(rowId: UUID) {
        guard let track = reader.tracks.first(where: { $0.id == rowId }) else { return }

        if track.isAvailable {
            if (playbackManager.currentTrackDisplayable as? Track)?.id == track.id {
                playbackManager.togglePlayPause()
            } else if let trackListId = reader.currentListId {
                playbackManager.play(
                    track: track,
                    context: reader.tracks,
                    source: .trackList(id: trackListId)
                )
            }
        } else {
            print("❌ Трек недоступен: \(track.title ?? track.fileName)")
        }
    }
}
