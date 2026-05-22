//
//  BatchFilenameRenameCommand.swift
//  TrackList
//
//  Команда массового переименования файлов.
//
//  Created by Pavel Fomin on 22.05.2026.
//

import Foundation

/// Команда массового переименования одного файла.
///
/// Команда содержит только готовое имя файла.
/// Artist/title сюда не передаются, потому что генерация имени уже выполнена на этапе rename plan.
struct BatchFilenameRenameCommand: Identifiable {
    /// Идентификатор трека.
    let trackId: UUID

    /// Текущее имя файла.
    let currentFileName: String

    /// Новое имя файла.
    let targetFileName: String

    var id: UUID { trackId }
}
