//
//  PlayerExportActionHandler.swift
//  TrackList
//
//  Обработчик экспорта очереди плеера.
//
//  Created by Pavel Fomin on 15.06.2026.
//

import Foundation
import UIKit

/// Выполняет экспорт текущей очереди плеера.
@MainActor
final class PlayerExportActionHandler {

    // MARK: - Dependencies

    /// Хранилище очереди плеера.
    private let playlistManager: PlaylistManager

    /// Глобальная ViewModel, владеющая жизненным циклом экспорта.
    private let exportProgressViewModel: ExportProgressViewModel

    /// Менеджер пользовательских уведомлений.
    private let toastManager: ToastManager

    /// Возвращает текущий UIViewController для показа системного picker.
    private let presenterProvider: () -> UIViewController?

    // MARK: - Инициализация

    init(
        playlistManager: PlaylistManager,
        exportProgressViewModel: ExportProgressViewModel,
        toastManager: ToastManager,
        presenterProvider: @escaping () -> UIViewController?
    ) {
        self.playlistManager = playlistManager
        self.exportProgressViewModel = exportProgressViewModel
        self.toastManager = toastManager
        self.presenterProvider = presenterProvider
    }

    // MARK: - Actions

    /// Запускает экспорт текущего плейлиста плеера.
    func exportTrackList() {
        let tracks = playlistManager.tracks.map { $0.asTrack() }

        guard !tracks.isEmpty else {
            toastManager.handle(.noTracksToExport)
            return
        }

        guard let topVC = presenterProvider() else {
            toastManager.handle(.presenterUnavailable)
            return
        }

        // Action handler только передаёт команду глобальному владельцу операции.
        exportProgressViewModel.startExport(
            tracks: tracks,
            exportFolder: .playerQueue,
            fileNamingMode: .numbered,
            presenter: topVC
        )
    }
}
