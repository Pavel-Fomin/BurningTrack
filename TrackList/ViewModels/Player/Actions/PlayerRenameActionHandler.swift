//
//  PlayerRenameActionHandler.swift
//  TrackList
//
//  Адаптер rename-действий очереди плеера.
//
//  Created by Pavel Fomin on 15.06.2026.
//

import Foundation

/// Адаптирует rename-действие плеера к общему rename-flow.
///
/// Handler отвечает только за:
/// - поиск элемента очереди плеера;
/// - получение runtime snapshot;
/// - сборку TrackFileRenameRequest;
/// - передачу запроса в общий TrackFileRenameActionHandler.
@MainActor
final class PlayerRenameActionHandler {

    // MARK: - Dependencies

    /// Хранилище очереди плеера.
    private let playlistManager: PlaylistManager

    /// ViewModel воспроизведения.
    private let playerViewModel: PlayerViewModel

    /// Общий обработчик переименования файлов треков.
    private let trackFileRenameActionHandler: TrackFileRenameActionHandler

    // MARK: - Инициализация

    init(
        playlistManager: PlaylistManager,
        playerViewModel: PlayerViewModel,
        trackFileRenameActionHandler: TrackFileRenameActionHandler
    ) {
        self.playlistManager = playlistManager
        self.playerViewModel = playerViewModel
        self.trackFileRenameActionHandler = trackFileRenameActionHandler
    }

    // MARK: - Actions

    /// Запускает сценарий переименования элемента очереди плеера.
    func renameTrack(
        queueItemId: UUID,
        strategy: FileRenameStrategy
    ) {
        guard let track = playlistManager.tracks.first(
            where: { $0.id == queueItemId }
        ) else {
            return
        }

        let snapshot = playerViewModel.snapshot(for: track.trackId)
        let request = TrackFileRenameRequest(
            trackId: track.trackId,
            rowId: track.id,
            currentFileName: snapshot?.fileName ?? track.fileName,
            artist: snapshot?.artist,
            title: snapshot?.title,
            strategy: strategy
        )
        trackFileRenameActionHandler.handle(request)
    }
}
