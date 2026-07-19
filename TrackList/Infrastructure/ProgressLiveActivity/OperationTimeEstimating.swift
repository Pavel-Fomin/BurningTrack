//
//  OperationTimeEstimating.swift
//  TrackList
//
//  Контракт оценки оставшегося времени длительной операции.
//
//  Created by Pavel Fomin on 19.07.2026.
//

import Foundation

/// Рассчитывает стабильную дату завершения по снимкам прогресса.
protocol OperationTimeEstimating {

    /// Полностью сбрасывает статистику и начинает новую операцию.
    mutating func reset(startDate: Date)

    /// Добавляет измерение прогресса и возвращает новую оценку, если она доступна.
    mutating func recordProgress(
        completedUnits: Int64,
        totalUnits: Int64,
        date: Date
    ) -> Date?

    /// Прекращает расчёт после терминальной фазы операции.
    mutating func stop()
}
