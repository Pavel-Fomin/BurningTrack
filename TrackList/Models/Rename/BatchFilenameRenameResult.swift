//
//  BatchFilenameRenameResult.swift
//  TrackList
//
//  Результат массового переименования файлов.
//
//  Created by Pavel Fomin on 22.05.2026.
//

import Foundation

/// Общий результат массового переименования файлов.
struct BatchFilenameRenameResult {
    /// Успешно переименованные файлы.
    let succeeded: [BatchFilenameRenameSuccess]

    /// Файлы, которые не удалось переименовать.
    let failed: [BatchFilenameRenameFailure]

    /// Количество успешных операций.
    var successCount: Int { succeeded.count }

    /// Количество ошибок.
    var failureCount: Int { failed.count }

    /// Есть ли хотя бы один успешный результат.
    var hasSuccesses: Bool { !succeeded.isEmpty }

    /// Есть ли хотя бы одна ошибка.
    var hasFailures: Bool { !failed.isEmpty }
}

/// Успешное переименование одного файла.
struct BatchFilenameRenameSuccess: Identifiable {
    /// Идентификатор трека.
    let trackId: UUID

    /// Старое имя файла.
    let oldFileName: String

    /// Новое имя файла.
    let newFileName: String

    var id: UUID { trackId }
}

/// Ошибка переименования одного файла.
struct BatchFilenameRenameFailure: Identifiable {
    /// Идентификатор трека.
    let trackId: UUID

    /// Имя файла, которое пытались получить.
    let targetFileName: String

    /// Ошибка операции.
    let error: Error

    var id: UUID { trackId }
}
