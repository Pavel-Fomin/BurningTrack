//
//  OperationTimeEstimator.swift
//  TrackList
//
//  Сглаженная оценка даты завершения длительной операции.
//
//  Created by Pavel Fomin on 19.07.2026.
//

import Foundation

/// Оценивает оставшееся время по скорости изменения количества завершённых единиц.
struct OperationTimeEstimator: OperationTimeEstimating {

    /// Минимальная длительность наблюдения до показа первой оценки.
    static let minimumObservationDuration: TimeInterval = 4

    /// Вес нового измерения в экспоненциальном сглаживании скорости.
    static let smoothingFactor = 0.15

    /// Минимальный интервал между измерениями скорости.
    private static let minimumMeasurementInterval: TimeInterval = 1

    /// Время начала текущей операции.
    private var startDate: Date?

    /// Последнее количество завершённых рабочих единиц, использованное в измерении.
    private var lastCompletedUnits: Int64 = 0

    /// Дата последнего измерения с изменившимся прогрессом.
    private var lastMeasurementDate: Date?

    /// Сглаженная скорость выполнения в рабочих единицах в секунду.
    private var smoothedUnitsPerSecond: Double?

    /// Сбрасывает накопленную статистику для новой операции.
    mutating func reset(startDate: Date) {
        self.startDate = startDate
        lastCompletedUnits = 0
        lastMeasurementDate = startDate
        smoothedUnitsPerSecond = nil
    }

    /// Добавляет измерение только при реальном изменении количества единиц.
    /// Повторные снимки байтового прогресса не искажают скорость выполнения.
    mutating func recordProgress(
        completedUnits: Int64,
        totalUnits: Int64,
        date: Date
    ) -> Date? {
        guard let startDate,
              totalUnits > 0,
              completedUnits > lastCompletedUnits,
              completedUnits <= totalUnits,
              let lastMeasurementDate else {
            return nil
        }

        let elapsed = date.timeIntervalSince(lastMeasurementDate)
        let completedDelta = completedUnits - lastCompletedUnits
        guard elapsed >= Self.minimumMeasurementInterval,
              completedDelta > 0 else {
            return nil
        }

        let measuredSpeed = Double(completedDelta) / elapsed
        guard measuredSpeed.isFinite, measuredSpeed > 0 else {
            return nil
        }

        let smoothing = Self.smoothingFactor
        smoothedUnitsPerSecond = if let smoothedUnitsPerSecond {
            smoothedUnitsPerSecond * (1 - smoothing) + measuredSpeed * smoothing
        } else {
            measuredSpeed
        }
        self.lastMeasurementDate = date
        self.lastCompletedUnits = completedUnits

        guard date.timeIntervalSince(startDate) >= Self.minimumObservationDuration,
              let smoothedUnitsPerSecond,
              smoothedUnitsPerSecond > 0 else {
            return nil
        }

        let remainingUnits = max(totalUnits - completedUnits, 0)
        let remainingSeconds = max(
            Double(remainingUnits) / smoothedUnitsPerSecond,
            0
        )
        return date.addingTimeInterval(remainingSeconds)
    }

    /// Останавливает расчёт, не оставляя статистику для следующей операции.
    mutating func stop() {
        startDate = nil
        lastCompletedUnits = 0
        lastMeasurementDate = nil
        smoothedUnitsPerSecond = nil
    }
}
