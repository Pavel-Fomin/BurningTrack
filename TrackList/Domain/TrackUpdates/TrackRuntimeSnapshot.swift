//
//  TrackRuntimeSnapshot.swift
//  TrackList
//
// Каноничное runtime-состояние трека.
// Это единый источник правды после чтения файла.

// Используется всеми экранами (плеер, треклист, фонотека, sheet)
// через единый контракт обновления.
// - не содержит UIImage (только Data)
// - не зависит от UI
// - не используется для сериализации
//
//  Created by PavelFomin on 23.04.2026.
//

import Foundation

struct TrackRuntimeSnapshot: Equatable {

    // MARK: - Identity

    let trackId: UUID

    // MARK: - File

    let fileName: String
    let isAvailable: Bool

    // MARK: - Основное

    let title: String?        /// Название трека
    let artist: String?       /// Основной исполнитель
    let album: String?        /// Название альбома
    let albumArtist: String?  /// Исполнитель альбома
    let genre: String?        /// Жанр
    let comment: String?      /// Комментарий

    // MARK: - Авторы

    let composer: String?     /// Композитор
    let conductor: String?    /// Дирижёр
    let lyricist: String?     /// Автор текста
    let remixer: String?      /// Автор ремикса

    // MARK: - Музыкальные атрибуты

    let grouping: String?     /// Поле группировки
    let bpm: Int?             /// Темп трека
    let musicalKey: String?   /// Музыкальная тональность

    // MARK: - Нумерация

    let trackNumber: Int?     /// Номер трека
    let totalTracks: Int?     /// Общее количество треков
    let discNumber: Int?      /// Номер диска
    let totalDiscs: Int?      /// Общее количество дисков

    // MARK: - Выпуск и идентификация

    let year: Int?                 /// Год выпуска
    let date: String?              /// Полная дата, если она есть в файле
    let publisherOrLabel: String?  /// Лейбл или издатель
    let copyright: String?         /// Поле copyright
    let encodedBy: String?         /// Кем был закодирован или обработан файл
    let isrc: String?              /// Международный код записи

    // MARK: - Runtime

    let duration: Double?  /// Длительность трека в секундах
    let artworkData: Data? /// Обложка в сыром виде, как прочитано из файла
    let updatedAt: Date    /// Время последней сборки snapshot

}
