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

    var title: String?
    var artist: String?
    var album: String?
    var albumArtist: String?
    var genre: String?
    var comment: String?

    // MARK: - Авторы

    var composer: String?
    var conductor: String?
    var lyricist: String?
    var remixer: String?

    // MARK: - Музыкальные атрибуты

    var grouping: String?
    var bpm: Int?
    var musicalKey: String?

    // MARK: - Нумерация
    var trackNumber: Int?
    var totalTracks: Int?
    var discNumber: Int?
    var totalDiscs: Int?

    // MARK: - Выпуск и идентификация

    var year: Int?
    var date: String?
    var publisherOrLabel: String?
    var copyright: String?
    var encodedBy: String?
    var isrc: String?
}
