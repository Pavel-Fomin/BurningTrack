//
//  TagWritePatch.swift
//  TrackList
//
//  Модель изменений тегов трека.
//  Неизменённые поля выражаются через .unchanged, а отсутствие патча обложки — через nil.
//
//  Created by PavelFomin on 16.01.2026.
//

import Foundation

/// Патч для записи тегов трека.
/// Используется write-слоем и command-архитектурой.
struct TagWritePatch: Sendable, Equatable {

    // MARK: - Основные текстовые теги

    var artist: TagFieldChange<String> = .unchanged
    var title: TagFieldChange<String> = .unchanged
    var album: TagFieldChange<String> = .unchanged
    var publisher: TagFieldChange<String> = .unchanged
    var genre: TagFieldChange<String> = .unchanged
    var comment: TagFieldChange<String> = .unchanged

    // MARK: - Числовые теги

    var year: TagFieldChange<Int> = .unchanged
    var trackNumber: TagFieldChange<Int> = .unchanged
    var bpm: TagFieldChange<Int> = .unchanged
    /// Длительность обычно вычисляется из файла, но отдельные форматы поддерживают её как тег.
    var duration: TagFieldChange<TimeInterval> = .unchanged

    // MARK: - Обложка

    /// nil сохраняет обложку; remove удаляет её, а set заменяет исходными данными.
    var artwork: ArtworkPatch? = nil

}

// Операции над обложкой трека.
enum ArtworkPatch: Sendable, Equatable {

    case remove
    case set(
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
