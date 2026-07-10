//
//  LibraryCollectionCategory.swift
//  TrackList
//
//  Раздел музыкальной коллекции в режиме корня "Треки".
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

// Описывает навигационные разделы коллекции без загрузки самих значений раздела.
enum LibraryCollectionCategory: String, CaseIterable, Hashable, Identifiable {
    /// Раздел исполнителей.
    case artists
    /// Раздел альбомов.
    case albums
    /// Раздел жанров.
    case genres
    /// Раздел лейблов.
    case labels
    /// Раздел годов.
    case years

    /// Стабильный идентификатор для SwiftUI-списков и маршрутов.
    var id: Self {
        self
    }

    /// Название строки в списке разделов коллекции.
    var title: String {
        switch self {
        case .artists:
            return "Артисты"
        case .albums:
            return "Альбомы"
        case .genres:
            return "Жанры"
        case .labels:
            return "Лейблы"
        case .years:
            return "Годы"
        }
    }

    /// Системная иконка строки раздела.
    var systemImage: String {
        switch self {
        case .artists:
            return "music.mic"
        case .albums:
            return "square.stack"
        case .genres:
            return "tag"
        case .labels:
            return "building.2"
        case .years:
            return "calendar"
        }
    }

    /// Заголовок destination-экрана выбранного раздела.
    var navigationTitle: String {
        title
    }

    /// Поля события обновления, которые могут изменить принадлежность трека к разделу.
    var changedFields: Set<TrackChangedField> {
        switch self {
        case .artists:
            return [.artist]
        case .albums:
            return [.album, .albumArtist, .artist]
        case .genres:
            return [.genre]
        case .labels:
            return [.publisherOrLabel]
        case .years:
            return [.year]
        }
    }

    /// Возвращает значение нужного SQLite metadata-поля для выбранного раздела.
    func metadataValue(from metadata: TrackCachedMetadata) -> String? {
        switch self {
        case .artists:
            return nonEmptyString(metadata.artist)
        case .albums:
            return nonEmptyString(metadata.album)
        case .genres:
            return nonEmptyString(metadata.genre)
        case .labels:
            return nonEmptyString(metadata.label)
        case .years:
            return metadata.year.map(String.init)
        }
    }

    /// Возвращает artist-часть album-ключа с fallback от album artist к artist.
    func albumArtistKey(from metadata: TrackCachedMetadata) -> String? {
        nonEmptyString(metadata.albumArtist) ?? nonEmptyString(metadata.artist)
    }

    /// Проверяет совпадение metadata со значением коллекции без учёта регистра и диакритики.
    func matches(
        metadata: TrackCachedMetadata,
        rawValue: String,
        artistKey: String? = nil
    ) -> Bool {
        guard let metadataValue = metadataValue(from: metadata) else { return false }
        guard normalizedMetadataKey(for: metadataValue) == normalizedMetadataKey(for: rawValue) else {
            return false
        }

        guard self == .albums else { return true }

        guard let artistKey else {
            return albumArtistKey(from: metadata) == nil
        }

        guard let metadataArtistKey = albumArtistKey(from: metadata) else { return false }
        return normalizedMetadataKey(for: metadataArtistKey) == normalizedMetadataKey(for: artistKey)
    }

    /// Нормализует значение metadata для группировки и фильтрации.
    func normalizedMetadataKey(for value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    /// Убирает пустые строки SQLite metadata.
    private func nonEmptyString(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.isEmpty == false else {
            return nil
        }

        return value
    }
}

extension LibraryCollectionCategory {
    /// Режимы сортировки, доступные для значений текущего раздела.
    var availableValueSortModes: [LibraryCollectionValueSortMode] {
        switch self {
        case .artists, .genres, .labels:
            return [
                .titleAscending,
                .titleDescending
            ]
        case .albums:
            return [
                .titleAscending,
                .titleDescending,
                .yearNewestFirst,
                .yearOldestFirst,
                .artistAscending,
                .artistDescending
            ]
        case .years:
            return [
                .yearNewestFirst,
                .yearOldestFirst
            ]
        }
    }

    /// Группы меню в порядке, который задан доступными режимами текущего раздела.
    var availableValueSortMenuGroups: [LibraryCollectionValueSortMode.MenuGroup] {
        availableValueSortModes.reduce(into: []) { groups, mode in
            guard groups.contains(mode.menuGroup) == false else { return }
            groups.append(mode.menuGroup)
        }
    }

    /// Начальный режим сортировки значений текущего раздела.
    var defaultValueSortMode: LibraryCollectionValueSortMode {
        switch self {
        case .years:
            return .yearNewestFirst
        case .artists, .albums, .genres, .labels:
            return .titleAscending
        }
    }
}
