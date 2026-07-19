//
//  OperationProgress.swift
//  TrackList
//
//  Универсальный снимок прогресса длительной операции.
//
//  Created by Pavel Fomin on 19.07.2026.
//

import Foundation

/// Описывает универсальный снимок, который можно показать вне приложения.
/// Модель намеренно не содержит терминов экспорта, файлов или копирования.
struct OperationProgress: Equatable, Sendable {

    /// Количество завершённых единиц текущей операции.
    let completedUnits: Int

    /// Общее количество единиц текущей операции.
    let totalUnits: Int

    /// Расчётная дата завершения операции, если данных уже достаточно.
    let estimatedEndDate: Date?

    /// Универсальная фаза жизненного цикла операции.
    let phase: ProgressActivityPhase

    /// Доля выполнения для индикаторов, ограниченная диапазоном от нуля до единицы.
    var fractionCompleted: Double {
        guard totalUnits > 0 else { return 0 }
        return min(max(Double(completedUnits) / Double(totalUnits), 0), 1)
    }
}
