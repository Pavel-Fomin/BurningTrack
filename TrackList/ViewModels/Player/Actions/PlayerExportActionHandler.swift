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

    /// Менеджер экспорта файлов.
    private let exportManager: ExportManager

    /// Менеджер пользовательских уведомлений.
    private let toastManager: ToastManager

    /// Возвращает текущий UIViewController для показа системного picker.
    private let presenterProvider: () -> UIViewController?

    // MARK: - Инициализация

    init(
        playlistManager: PlaylistManager,
        exportManager: ExportManager,
        toastManager: ToastManager,
        presenterProvider: @escaping () -> UIViewController?
    ) {
        self.playlistManager = playlistManager
        self.exportManager = exportManager
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

        Task {
            do {
                _ = try await exportManager.exportViaTempAndPicker(
                    tracks,
                    presenter: topVC
                )
            } catch let appError as AppError {
                toastManager.handle(appError)
            } catch {
                toastManager.handle(.exportFailed)
            }
        }
    }
}
