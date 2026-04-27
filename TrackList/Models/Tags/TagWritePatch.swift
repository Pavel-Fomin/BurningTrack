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

    var artist: TagFieldChange<String> = .unchanged     /// Исполнитель
    var title: TagFieldChange<String> = .unchanged      /// Название трека
    var album: TagFieldChange<String> = .unchanged      /// Альбом
    var publisher: TagFieldChange<String> = .unchanged  /// Издатель / лейбл
    var genre: TagFieldChange<String> = .unchanged      /// Жанр
    var comment: TagFieldChange<String> = .unchanged    /// Комментарий

    // MARK: - Числовые теги

    /// Год выпуска
    var year: TagFieldChange<Int> = .unchanged                /// Год выпуска
    var trackNumber: TagFieldChange<Int> = .unchanged         /// Номер трека
    var bpm: TagFieldChange<Int> = .unchanged                 /// BPM (удары в минуту)
    var duration: TagFieldChange<TimeInterval> = .unchanged   /// Длительность. По умолчанию вычесляемое, но предусмотрено для форматов, где тег поддерживается.

    // MARK: - Обложка

    var artwork: ArtworkPatch? = nil  /// Патч для обложки: nil → не трогаем, remove → удалить, set → заменить

}

// Операции над обложкой трека
enum ArtworkPatch: Sendable, Equatable {

    case remove           /// Удалить существующую обложку
    case set(             /// Установить новую обложку без преобразований
        data: Data,
        mime: String?
    )

    /// Установить новую обложку с предварительным сжатием. Сжатие выполняется write-реализацией (не здесь). Patch описывает намерение, а не алгоритм.
    case setCompressed(
        data: Data,
        mime: String?,
        maxPixel: Int,
        quality: Double
    )
}
