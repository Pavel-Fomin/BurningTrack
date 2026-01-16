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
    var artist: String?

    /// Название трека
    var title: String?

    /// Альбом
    var album: String?

    /// Лейбл / издатель
    var label: String?

    /// Жанр
    var genre: String?

    /// Комментарий
    var comment: String?

    // MARK: - Числовые теги

    /// Год выпуска
    var year: Int?

    /// Номер трека
    var trackNumber: Int?

    /// BPM (удары в минуту)
    var bpm: Int?

    /// Время / длительность
    /// ⚠️ По умолчанию считается вычисляемым,
    /// но предусмотрено для форматов, где тег поддерживается.
    var duration: TimeInterval?

    // MARK: - Обложка

    /// Патч для обложки:
    /// - nil → не трогаем
    /// - remove → удалить
    /// - set → заменить
    var artwork: ArtworkPatch?

    // MARK: - Init

    init(
        artist: String? = nil,
        title: String? = nil,
        album: String? = nil,
        label: String? = nil,
        genre: String? = nil,
        comment: String? = nil,
        year: Int? = nil,
        trackNumber: Int? = nil,
        bpm: Int? = nil,
        duration: TimeInterval? = nil,
        artwork: ArtworkPatch? = nil
    ) {
        self.artist = artist
        self.title = title
        self.album = album
        self.label = label
        self.genre = genre
        self.comment = comment
        self.year = year
        self.trackNumber = trackNumber
        self.bpm = bpm
        self.duration = duration
        self.artwork = artwork
    }
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
    ///
    /// Сжатие выполняется write-реализацией (НЕ здесь).
    /// Patch описывает намерение, а не алгоритм.
    case setCompressed(
        data: Data,
        mime: String?,
        maxPixel: Int,
        quality: Double
    )
}
