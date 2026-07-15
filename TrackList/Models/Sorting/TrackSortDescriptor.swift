//
//  TrackSortDescriptor.swift
//  TrackList
//
//  Общие модели сортировки треков.
//
//  Created by Pavel Fomin on 06.07.2026.
//

import Foundation

/// Поле, по которому может быть отсортирован трек независимо от конкретной модели источника.
enum TrackSortField: String, CaseIterable, Codable, Hashable {
    /// Сортировка по имени артиста.
    case artist
    /// Сортировка по названию трека.
    case title
    /// Сортировка по названию альбома.
    case album
    /// Сортировка по году выпуска.
    case year
    /// Сортировка по лейблу.
    case label
    /// Сортировка по жанру.
    case genre
    /// Сортировка по комментарию.
    case comment
    /// Сортировка по имени файла.
    case fileName
    /// Общее поле даты; точная семантика определяется источником трека в следующих фазах.
    case date
}

/// Направление сортировки треков.
enum TrackSortDirection: String, CaseIterable, Codable, Hashable {
    /// Значения идут от меньшего к большему или от А к Я.
    case ascending
    /// Значения идут от большего к меньшему или от Я к А.
    case descending
}

/// Описывает выбранную сортировку треков без применения её к данным.
struct TrackSortDescriptor: Codable, Hashable {
    /// Поле трека, выбранное для сортировки.
    let field: TrackSortField
    /// Направление сортировки для выбранного поля.
    let direction: TrackSortDirection
}
