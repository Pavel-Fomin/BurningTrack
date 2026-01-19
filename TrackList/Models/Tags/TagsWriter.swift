//
//  TagsWriter.swift
//  TrackList
//
//  Протокол сервиса записи тегов трека.
//  Не знает про UI, TagLib, bookmark'и и т.п.
//
//  Created by PavelFomin on 16.01.2026.
//

import Foundation

/// Абстракция сервиса записи тегов.
/// Конкретная реализация (TagLib и т.д.) скрыта за протоколом.
protocol TagsWriter: Sendable {

    /// Записывает изменения тегов в файл по URL.
    ///
    /// - Parameters:
    ///   - url: URL аудиофайла (с уже открытым доступом)
    ///   - patch: патч изменений тегов
    ///
    /// - Throws: TagWriteError
    func writeTags(
        to url: URL,
        patch: TagWritePatch
    ) async throws
}
