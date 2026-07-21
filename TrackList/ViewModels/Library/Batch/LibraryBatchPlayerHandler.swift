//
//  LibraryBatchPlayerHandler.swift
//  TrackList
//
//  Обрабатывает массовое добавление треков фонотеки в плеер.
//
//  Создано Codex 25.06.2026.
//

import Foundation

/// Выполняет batch-действия фонотеки, связанные с очередью плеера.
/// Не хранит selection и не управляет UI списка.
@MainActor
final class LibraryBatchPlayerHandler {

    // MARK: - Зависимости

    private let commandExecutor: AppCommandExecutor
    private let toastManager: ToastManager

    // MARK: - Инициализация

    init(
        commandExecutor: AppCommandExecutor = .shared,
        toastManager: ToastManager? = nil
    ) {
        self.commandExecutor = commandExecutor
        self.toastManager = toastManager ?? .shared
    }

    // MARK: - Публичные методы

    /// Добавляет выбранные треки в плеер.
    func addToPlayer(with pendingAction: PendingBulkTrackAction) {
        guard !pendingAction.isEmpty else { return }

        Task { [commandExecutor, toastManager, trackIds = pendingAction.trackIDs] in
            do {
                try await commandExecutor.addTracksToPlayer(trackIds: trackIds)
            } catch let appError as AppError {
                toastManager.handle(appError)
            } catch {
                toastManager.handle(
                    .operationFailed(
                        message: PlayerPresentationText.addTracksToPlayerFailedMessage
                    )
                )
            }
        }
    }
}
