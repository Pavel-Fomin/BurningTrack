//
//  PlayerExportActionHandler.swift
//  TrackList
//
//  Обработчик экспорта очереди плеера.
//
//  Created by Pavel Fomin on 15.06.2026.
//

import Foundation

/// Выполняет экспорт текущей очереди плеера.
@MainActor
final class PlayerExportActionHandler {

    // MARK: - Dependencies

    /// Хранилище очереди плеера.
    private let playlistManager: PlaylistManager

    /// Типизированный вход в глобальный Export-feature.
    private let exportRequestHandler: any ExportRequestHandling

    // MARK: - Инициализация

    init(
        playlistManager: PlaylistManager,
        exportRequestHandler: any ExportRequestHandling
    ) {
        self.playlistManager = playlistManager
        self.exportRequestHandler = exportRequestHandler
    }

    // MARK: - Actions

    /// Запускает экспорт текущего плейлиста плеера.
    func exportTrackList() {
        let tracks = playlistManager.tracks.map { $0.asTrack() }

        // Export-feature единообразно проверяет запрос и владеет системным picker-ом.
        exportRequestHandler.startExport(
            ExportRequest(
                tracks: tracks,
                exportFolder: .playerQueue,
                fileNamingMode: .numbered
            )
        )
    }
}
