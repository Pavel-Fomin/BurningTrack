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

    /// Предоставляет только состояние, нужное для различения текущей строки треклиста.
    private let playbackStateProvider: any PlaybackStateProviding
    /// Выполняет только команды запуска и toggle без раскрытия PlayerViewModel.
    private let playbackController: any TrackPlaybackControlling

    /// Создаёт обработчик playback-действий одного треклиста.
    init(
        reader: any TrackListReading,
        playbackStateProvider: any PlaybackStateProviding,
        playbackController: any TrackPlaybackControlling
    ) {
        self.reader = reader
        self.playbackStateProvider = playbackStateProvider
        self.playbackController = playbackController
    }

    /// Обрабатывает нажатие на строку трека.
    func handleRowTap(rowId: UUID) {
        guard let track = reader.track(forRowId: rowId) else { return }

        if track.isAvailable {
            if playbackStateProvider.currentDisplayableId == track.id,
               playbackStateProvider.currentContext == .trackList {
                playbackController.togglePlayPause()
            } else {
                playbackController.play(
                    track: track,
                    context: reader.tracks.map { $0 as any TrackDisplayable },
                    source: .trackList(id: reader.trackListId)
                )
            }
        } else {
            print("❌ Трек недоступен: \(track.title ?? track.fileName)")
        }
    }
}
