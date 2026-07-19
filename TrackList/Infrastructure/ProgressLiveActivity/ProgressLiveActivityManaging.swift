//
//  ProgressLiveActivityManaging.swift
//  TrackList
//
//  Контракт универсального слоя управления Live Activity.
//
//  Created by Pavel Fomin on 19.07.2026.
//

import Foundation

/// Изолирует ActivityKit от Export Feature и других владельцев длительных операций.
@MainActor
protocol ProgressLiveActivityManaging: AnyObject {

    /// Запускает Activity уже принятой операции с начальным снимком состояния.
    func start(
        operationID: UUID,
        operationTitle: String,
        subjectTitle: String,
        progress: OperationProgress
    )

    /// Передаёт Activity новый снимок, если он заметно изменился.
    func update(
        operationID: UUID,
        progress: OperationProgress
    )

    /// Показывает итоговый снимок и корректно завершает Activity.
    func finish(
        operationID: UUID,
        progress: OperationProgress
    )
}
