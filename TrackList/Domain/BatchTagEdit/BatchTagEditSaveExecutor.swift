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
/// - передаёт полный набор команд единому batch ownership;
/// - использует AppCommandExecutor как единый write-layer;
/// - возвращает общий результат batch-операции;
/// - не знает про UI и SheetManager.
struct BatchTagEditSaveExecutor {
    /// Исполнитель команд приложения.
    private let appCommandExecutor: AppCommandExecutor

    init(appCommandExecutor: AppCommandExecutor) {
        self.appCommandExecutor = appCommandExecutor
    }

    /// Выполняет план массового сохранения тегов.
    func execute(
        plan: BatchTagEditSavePlan
    ) async -> BatchTagEditSaveResult {
        // Executor сохраняет результат каждой строки, а AppCommandExecutor публикует один batch после подготовки всех snapshot.
        await appCommandExecutor.updateTrackTagsBatch(plan.commands)
    }
}
