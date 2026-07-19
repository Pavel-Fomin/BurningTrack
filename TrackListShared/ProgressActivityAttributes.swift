//
//  ProgressActivityAttributes.swift
//  TrackList
//
//  Общая ActivityKit-модель универсальной длительной операции.
//
//  Created by Pavel Fomin on 19.07.2026.
//

import ActivityKit
import Foundation

/// Статические и динамические данные Live Activity для любой длительной операции.
@available(iOS 16.1, *)
struct ProgressActivityAttributes: ActivityAttributes {

    /// Тип выполняемой операции, например «Экспортирую».
    let operationTitle: String

    /// Название объекта операции, например имя экспортной папки.
    let subjectTitle: String

    /// Изменяемое состояние, передаваемое приложением без технических деталей.
    struct ContentState: Codable, Hashable, Sendable {

        /// Количество завершённых единиц операции.
        let completedUnits: Int

        /// Общее количество единиц операции.
        let totalUnits: Int

        /// Расчётная дата завершения операции.
        let estimatedEndDate: Date?

        /// Текущее состояние операции.
        let phase: ProgressActivityPhase
    }
}
