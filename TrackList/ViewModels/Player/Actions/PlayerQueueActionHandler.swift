//
//  PlayerQueueActionHandler.swift
//  TrackList
//
//  Обработчик действий над очередью плеера.
//
//  Created by Pavel Fomin on 15.06.2026.
//

import Foundation

/// Выполняет действия над очередью плеера.
///
/// Handler отвечает за:
/// - перемещение элементов очереди;
/// - удаление элемента очереди;
/// - очистку очереди.
@MainActor
final class PlayerQueueActionHandler {

    // MARK: - Dependencies

    /// Хранилище очереди плеера.
    private let playlistManager: PlaylistManager

    /// Исполнитель команд приложения.
    private let commandExecutor: AppCommandExecutor

    /// Менеджер пользовательских уведомлений.
    private let toastManager: ToastManager

    // MARK: - Инициализация

    init(
        playlistManager: PlaylistManager,
        commandExecutor: AppCommandExecutor,
        toastManager: ToastManager
    ) {
        self.playlistManager = playlistManager
        self.commandExecutor = commandExecutor
        self.toastManager = toastManager
    }

    // MARK: - Actions

    /// Перемещает элементы очереди плеера
    /// с сохранением очереди и rollback при ошибке.
    func moveTracks(
        from: IndexSet,
        to: Int
    ) {
        let previousTracks = playlistManager.tracks
        playlistManager.tracks.move(
            fromOffsets: from,
            toOffset: to
        )
        guard playlistManager.saveQueue() else {
            playlistManager.tracks = previousTracks
            toastManager.handle(.playlistSaveFailed)
            return
        }
    }

    /// Удаляет элемент очереди плеера.
    func deleteTrack(queueItemId: UUID) {
        Task {
            do {
                try await commandExecutor.removeTrackFromPlayer(
                    queueItemId: queueItemId
                )
            } catch let appError as AppError {
                toastManager.handle(appError)
            } catch {
                toastManager.handle(
                    .operationFailed(
                        message: PlayerPresentationText.removeTrackFromPlayerFailedMessage
                    )
                )
            }
        }
    }

    /// Очищает текущую очередь плеера.
    func clearTrackList() {
        Task {
            await commandExecutor.clearPlayer()
        }
    }
}
