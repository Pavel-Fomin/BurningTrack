//
//  TrackSheetMetadata.swift
//  TrackList
//
//  Модель данных для шита "О треке".
//
//  Хранит основные поля тегов, которые экран читает и показывает.
//  Модель не зависит от UI, TagLib, плеера и строк списков.
//  Это единый контракт данных для sheet-сценария.
//
//  Created by Pavel Fomin on 05.04.2026.
//

import Foundation

struct TrackSheetMetadata: Equatable {

    // MARK: - Основное

    var title: String?        /// Название трека
    var artist: String?       /// Основной исполнитель
    var album: String?        /// Название альбома
    var albumArtist: String?  /// Исполнитель альбома
    var genre: String?        /// Жанр
    var comment: String?      /// Комментарий

    // MARK: - Авторы

    var composer: String?     /// Композитор
    var conductor: String?    /// Дирижёр
    var lyricist: String?     /// Автор текста
    var remixer: String?      /// Автор ремикса

    // MARK: - Музыкальные атрибуты

    var grouping: String?     /// Поле группировки
    var bpm: Int?             /// Темп трека
    var musicalKey: String?   /// Музыкальная тональность

    // MARK: - Нумерация
    var trackNumber: Int?     /// Номер трека
    var totalTracks: Int?     /// Общее количество треков
    var discNumber: Int?      /// Номер диска
    var totalDiscs: Int?      /// Общее количество дисков

    // MARK: - Выпуск и идентификация

    var year: Int?             /// Год выпуска
    var date: String?          /// Полная дата, если она есть в файле
    var publisherOrLabel: String?  /// Лейбл или издатель
    var copyright: String?     /// Поле copyright
    var encodedBy: String?     /// Кем был закодирован или обработан файл
    var isrc: String?          /// Международный код записи
}
