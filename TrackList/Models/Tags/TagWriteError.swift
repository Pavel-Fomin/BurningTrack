//
//  TagWriteError.swift
//  TrackList
//
//  Ошибки записи тегов трека.
//  Используются write-слоем и command-архитектурой.
//
//  Created by PavelFomin on 16.01.2026.
//

import Foundation

/// Ошибки записи тегов через TagLib или другую реализацию.
enum TagWriteError: Error, Sendable, Equatable {

    /// Файл не найден
    case fileNotFound

    /// Нет прав на чтение файла
    case fileNotReadable

    /// Нет прав на запись файла
    case fileNotWritable

    /// Формат файла не поддерживается
    case unsupportedFormat

    /// Контейнер тегов отсутствует и не может быть создан
    case tagContainerMissing

    /// Некорректные данные обложки
    case invalidArtwork

    /// Ошибка сохранения файла
    case saveFailed(details: String?)

    /// Не удалось получить security-scoped доступ
    case securityScopeDenied

    /// Неизвестная ошибка
    case unknown(details: String?)
}
