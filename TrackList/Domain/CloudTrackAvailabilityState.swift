//
//  CloudTrackAvailabilityState.swift
//  TrackList
//
//  Runtime-состояние доступности файла трека в iCloud.
//
//  Created by Pavel Fomin on 20.07.2026.
//

import Foundation

/// Описывает текущую доступность файла трека без сохранения в постоянное хранилище.
enum CloudTrackAvailabilityState: Equatable, Sendable {
    /// Файл доступен локально или не относится к iCloud.
    case local
    /// iCloud-файл существует только в облаке и ещё не загружен.
    case notDownloaded
    /// Система загружает iCloud-файл на устройство.
    case downloading
    /// Последняя попытка загрузки iCloud-файла завершилась ошибкой.
    case downloadFailed

    /// Разрешает действия, которым требуется доступное локальное содержимое файла.
    var isContentAvailable: Bool {
        self == .local
    }

    /// Определяет, нужно ли продолжать обновлять состояние файла.
    var requiresPeriodicRefresh: Bool {
        self != .local
    }
}
