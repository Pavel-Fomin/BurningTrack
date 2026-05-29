//
//  BatchTagEditSaveExecutor.swift
//  TrackList
//
//  Executor массового сохранения тегов.
//
//  Created by Pavel Fomin on 27.05.2026.
//

import Foundation

/// Executor массового сохранения тегов.
///
/// Роль:
/// - последовательно выполняет команды записи;
/// - использует AppCommandExecutor как единый write-layer;
/// - отключает per-track success toast;
/// - возвращает общий результат batch-операции;
/// - не знает про UI и SheetManager.
struct BatchTagEditSaveExecutor {
    /// Исполнитель команд приложения.
    private let appCommandExecutor: AppCommandExecutor

    init(
        appCommandExecutor: AppCommandExecutor = .shared
    ) {
        self.appCommandExecutor = appCommandExecutor
    }

    /// Выполняет план массового сохранения тегов.
    func execute(
        plan: BatchTagEditSavePlan
    ) async -> BatchTagEditSaveResult {
        var succeededTrackIDs: [UUID] = []
        var failures: [BatchTagEditSaveFailure] = []

        for command in plan.commands {
            do {
                try await appCommandExecutor.updateTrackTags(
                    trackId: command.trackId,
                    patch: command.patch,
                    artworkAction: command.artworkAction,
                    showsSuccessToast: false
                )
                succeededTrackIDs.append(command.trackId)
            } catch {
                failures.append(
                    BatchTagEditSaveFailure(
                        trackId: command.trackId,
                        error: error
                    )
                )
            }
        }

        return BatchTagEditSaveResult(
            succeededTrackIDs: succeededTrackIDs,
            failures: failures
        )
    }
}
