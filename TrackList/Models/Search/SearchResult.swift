//
//  SearchResult.swift
//  TrackList
//
//  Модели результатов единого поиска по приложению.
//  Created by Pavel Fomin on 07.07.2026.
//

import Foundation
import UIKit

// Набор результатов поиска по основным сущностям приложения.
struct SearchResults: Equatable {
    let folders: [SearchFolderResult]
    let trackLists: [SearchTrackListResult]
    let tracks: [SearchTrackResult]

    /// Пустой результат используется для пустой строки и ошибок чтения.
    static let empty = SearchResults(
        folders: [],
        trackLists: [],
        tracks: []
    )

    /// UI показывает состояние "ничего не найдено", только если пусты все сущности.
    var isEmpty: Bool {
        folders.isEmpty && trackLists.isEmpty && tracks.isEmpty
    }
}

// Результат поиска по треку содержит только уже сохранённые данные из SQLite.
struct SearchTrackResult: Identifiable, Equatable, TrackDisplayable {
    let id: UUID
    let fileName: String
    let fileDate: Date?
    let relativePath: String
    let folderId: UUID?
    let rootFolderId: UUID?
    let folderTitle: String
    let libraryPath: String
    let title: String?
    let artist: String?
    let duration: Double
    let album: String?
    let year: Int?
    let label: String?
    let genre: String?
    let comment: String?
    var trackListNames: [String]
    let isAvailable: Bool

    /// Физический идентификатор трека совпадает с id результата поиска.
    var trackId: UUID {
        id
    }

    /// Поиск не читает и не строит обложку, чтобы не запускать runtime metadata.
    var artwork: UIImage? {
        nil
    }

    /// Отображаемое название: тег title имеет приоритет над именем файла.
    var displayTitle: String {
        Self.nonEmpty(title) ?? fileName
    }

    /// Поля трека для обычного текстового поиска без контекста папки.
    var searchableValues: [String] {
        [
            fileName,
            title,
            artist,
            album,
            year.map(String.init),
            label,
            genre,
            comment
        ]
        .compactMap(Self.nonEmpty)
    }

    /// Нормализует пустые строки, чтобы UI и поиск не считали их значениями.
    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            return nil
        }

        return trimmed
    }
}

// Результат поиска по папке не является треком и не реализует TrackDisplayable.
struct SearchFolderResult: Identifiable, Equatable {
    let id: UUID
    let name: String
    let relativePath: String?
    let isRoot: Bool

    /// Для root-папки показываем имя, для подпапки также оставляем имя строки фонотеки.
    var displayTitle: String {
        name
    }

    /// Папки ищутся только по названию, без подтягивания совпадений из пути.
    var searchableValues: [String] {
        [
            name
        ]
        .compactMap(Self.nonEmpty)
    }

    /// Нормализует пустые строки, чтобы поиск не считал их значениями.
    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            return nil
        }

        return trimmed
    }
}

// Результат поиска по треклисту хранит доменную модель треклиста.
struct SearchTrackListResult: Identifiable, Equatable {
    let trackList: TrackList

    var id: UUID {
        trackList.id
    }

    /// Треклисты ищутся по пользовательскому названию.
    var searchableValues: [String] {
        [trackList.name].compactMap(Self.nonEmpty)
    }

    /// Нормализует пустые строки, чтобы поиск не считал их значениями.
    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            return nil
        }

        return trimmed
    }
}
