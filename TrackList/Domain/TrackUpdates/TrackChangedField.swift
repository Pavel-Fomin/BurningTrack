//
//  TrackChangedField.swift
//  TrackList
//
//  Поле, изменившееся внутри каноничного runtime-состояния трека.
//  Используется в TrackUpdateEvent, чтобы подписчики могли понять, какие именно данные обновились
//
//  Created by PavelFomin on 24.04.2026.
//

import Foundation

enum TrackChangedField: Equatable, Hashable {

    // MARK: - File

    case fileName           /// Изменилось имя файла (rename)
    case isAvailable        /// Изменилась доступность файла

    // MARK: - Основное

    case title              /// Название трека
    case artist             /// Основной исполнитель
    case album              /// Альбом
    case albumArtist        /// Исполнитель альбома
    case genre              /// Жанр
    case comment            /// Комментарий

    // MARK: - Авторы

    case composer           /// Композитор
    case conductor          /// Дирижёр
    case lyricist           /// Автор текста
    case remixer            /// Автор ремикса

    // MARK: - Музыкальные атрибуты

    case grouping           /// Поле группировки
    case bpm                /// Темп трека
    case musicalKey         /// Музыкальная тональность

    // MARK: - Нумерация

    case trackNumber        /// Номер трека
    case totalTracks        /// Общее количество треков
    case discNumber         /// Номер диска
    case totalDiscs         /// Общее количество дисков

    // MARK: - Выпуск и идентификация

    case year               /// Год выпуска
    case date               /// Полная дата
    case publisherOrLabel   /// Лейбл или издатель
    case copyright          /// Поле copyright
    case encodedBy          /// Кем закодирован файл
    case isrc               /// Международный код записи

    // MARK: - Runtime

    case duration           /// Длительность трека
    case artworkData        /// Обложка (raw data)
}
