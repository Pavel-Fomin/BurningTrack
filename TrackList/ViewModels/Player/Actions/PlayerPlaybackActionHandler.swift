//
//  PlayerPlaybackActionHandler.swift
//  TrackList
//
//  Обработчик playback-действий экрана плеера.
//
//  Created by Pavel Fomin on 15.06.2026.
//

import Foundation

/// Выполняет playback-действия экрана плеера.
///
/// Handler отвечает только за:
/// - запуск или паузу элемента очереди;
/// - запрос runtime snapshot.
@MainActor
final class PlayerPlaybackActionHandler {

    // MARK: - Dependencies

    /// ViewModel воспроизведения.
    private let playerViewModel: PlayerViewModel

    /// Хранилище очереди плеера.
    private let playlistManager: PlaylistManager

    // MARK: - Инициализация

    init(
        playerViewModel: PlayerViewModel,
        playlistManager: PlaylistManager
    ) {
        self.playerViewModel = playerViewModel
        self.playlistManager = playlistManager
    }

    // MARK: - Actions

    /// Запускает выбранный элемент очереди или переключает play/pause для текущего.
    func playPause(queueItemId: UUID) {
        let tracks = playlistManager.tracks
        guard let track = tracks.first(where: { $0.id == queueItemId }) else {
            return
        }

        if playerViewModel.isCurrent(track, in: .player) {
            playerViewModel.togglePlayPause()
        } else {
            playerViewModel.play(track: track, context: tracks)
        }
    }

    /// Запрашивает runtime snapshot трека.
    func requestSnapshot(trackId: UUID) {
        playerViewModel.requestSnapshotIfNeeded(for: trackId)
    }
}
