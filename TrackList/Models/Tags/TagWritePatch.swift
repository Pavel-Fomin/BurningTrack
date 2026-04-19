//
//  TagWritePatch.swift
//  TrackList
//
//  Модель изменений тегов трека.
//  Описывает ТОЛЬКО то, что нужно изменить.
//  nil означает «не трогать поле».
//
//  Created by PavelFomin on 16.01.2026.
//

import Foundation

/// Патч для записи тегов трека.
/// Используется write-слоем и command-архитектурой.
struct TagWritePatch: Sendable, Equatable {

    // MARK: - Основные текстовые теги

    /// Исполнитель
    var artist: TagFieldChange<String> = .unchanged

    /// Название трека
    var title: TagFieldChange<String> = .unchanged

    /// Альбом
    var album: TagFieldChange<String> = .unchanged

    /// Издатель / лейбл
    var publisher: TagFieldChange<String> = .unchanged

    /// Жанр
    var genre: TagFieldChange<String> = .unchanged

    /// Комментарий
    var comment: TagFieldChange<String> = .unchanged

    // MARK: - Числовые теги

    /// Год выпуска
    var year: TagFieldChange<Int> = .unchanged

    /// Номер трека
    var trackNumber: TagFieldChange<Int> = .unchanged

    /// BPM (удары в минуту)
    var bpm: TagFieldChange<Int> = .unchanged

    /// Время / длительность
    /// По умолчанию считается вычисляемым,
    /// но предусмотрено для форматов, где тег поддерживается.
    var duration: TagFieldChange<TimeInterval> = .unchanged

    // MARK: - Обложка

    /// Патч для обложки:
    /// - nil → не трогаем
    /// - remove → удалить
    /// - set → заменить
    var artwork: ArtworkPatch? = nil

}

/// Операции над обложкой трека

enum ArtworkPatch: Sendable, Equatable {

    /// Удалить существующую обложку
    case remove
    /// Установить новую обложку без преобразований

    case set(
        data: Data,
        mime: String?
    )

    /// Установить новую обложку с предварительным сжатием
    /// Сжатие выполняется write-реализацией (не здесь).
    /// Patch описывает намерение, а не алгоритм.
    case setCompressed(
        data: Data,
        mime: String?,
        maxPixel: Int,
        quality: Double
    )
}
