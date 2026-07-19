//
//  ProgressActivityPhase.swift
//  TrackList
//
//  Универсальные фазы длительной операции для Live Activity.
//
//  Created by Pavel Fomin on 19.07.2026.
//

import Foundation

/// Описывает состояние длительной операции без привязки к конкретному сценарию.
enum ProgressActivityPhase: String, Codable, Hashable, Sendable {

    /// Операция готовит входные данные и ещё не выполняет основную работу.
    case preparing

    /// Операция выполняется и публикует текущий прогресс.
    case running

    /// Операция завершилась успешно.
    case completed

    /// Операция завершилась ошибкой.
    case failed

    /// Операция была отменена.
    case cancelled
}
