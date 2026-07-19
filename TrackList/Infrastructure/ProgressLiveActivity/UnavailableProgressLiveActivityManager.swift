//
//  UnavailableProgressLiveActivityManager.swift
//  TrackList
//
//  Безопасная пустая реализация слоя Live Activity.
//
//  Created by Pavel Fomin on 19.07.2026.
//

import Foundation

/// Позволяет выполнять длительные операции без поддержки Live Activity.
@MainActor
final class UnavailableProgressLiveActivityManager: ProgressLiveActivityManaging {

    /// Пустой запуск не влияет на основной сценарий операции.
    func start(
        operationID: UUID,
        operationTitle: String,
        subjectTitle: String,
        progress: OperationProgress
    ) {}

    /// Пустое обновление сохраняет прежнее поведение операции.
    func update(
        operationID: UUID,
        progress: OperationProgress
    ) {}

    /// Пустое завершение не блокирует освобождение операции.
    func finish(
        operationID: UUID,
        progress: OperationProgress
    ) {}
}
