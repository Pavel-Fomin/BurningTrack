//
//  TrackSorter.swift
//  TrackList
//
//  Общий сортировщик треков.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

/// Даёт общему сортировщику дополнительные metadata, не расширяя базовый UI-контракт TrackDisplayable.
protocol TrackSortMetadataProviding {
    /// Название альбома из сохранённого источника metadata.
    var trackSortAlbum: String? { get }
    /// Год выпуска из сохранённого источника metadata.
    var trackSortYear: Int? { get }
    /// Лейбл из сохранённого источника metadata.
    var trackSortLabel: String? { get }
    /// Жанр из сохранённого источника metadata.
    var trackSortGenre: String? { get }
    /// Комментарий из сохранённого источника metadata.
    var trackSortComment: String? { get }
}

/// Выполняет сортировку треков без привязки к конкретному источнику данных.
enum TrackSorter {
    /// Сортирует массив конкретного типа трека.
    static func sort<T: TrackDisplayable>(
        _ tracks: [T],
        using descriptor: TrackSortDescriptor
    ) -> [T] {
        stableSort(
            tracks,
            using: descriptor,
            key: { track, field in
                sortKey(for: track, field: field)
            }
        )
    }

    /// Сортирует массив треков, переданных через existential-протокол.
    static func sort(
        _ tracks: [any TrackDisplayable],
        using descriptor: TrackSortDescriptor
    ) -> [any TrackDisplayable] {
        stableSort(
            tracks,
            using: descriptor,
            key: { track, field in
                sortKey(for: track, field: field)
            }
        )
    }
}

// MARK: - Stable sorting

private extension TrackSorter {
    /// Сохраняет исходный порядок элементов при равных или отсутствующих значениях.
    static func stableSort<Element>(
        _ tracks: [Element],
        using descriptor: TrackSortDescriptor,
        key: (Element, TrackSortField) -> TrackSortKey
    ) -> [Element] {
        tracks
            .enumerated()
            .sorted { lhs, rhs in
                let leftKey = key(lhs.element, descriptor.field)
                let rightKey = key(rhs.element, descriptor.field)

                switch compare(leftKey, rightKey, direction: descriptor.direction) {
                case .orderedAscending:
                    return true
                case .orderedDescending:
                    return false
                case .orderedSame:
                    return lhs.offset < rhs.offset
                }
            }
            .map { $0.element }
    }
}

// MARK: - Sort keys

private extension TrackSorter {
    /// Собирает ключ сортировки из общего контракта TrackDisplayable.
    static func sortKey(
        for track: any TrackDisplayable,
        field: TrackSortField
    ) -> TrackSortKey {
        let metadataProvider = track as? any TrackSortMetadataProviding

        switch field {
        case .artist:
            return .string(nonEmptyString(track.artist))
        case .title:
            return .string(nonEmptyString(track.title))
        case .album:
            return .string(nonEmptyString(metadataProvider?.trackSortAlbum))
        case .year:
            return .number(metadataProvider?.trackSortYear)
        case .label:
            return .string(nonEmptyString(metadataProvider?.trackSortLabel))
        case .genre:
            return .string(nonEmptyString(metadataProvider?.trackSortGenre))
        case .comment:
            return .string(nonEmptyString(metadataProvider?.trackSortComment))
        case .fileName:
            return .string(nonEmptyString(track.fileName))
        case .date:
            let dateProvider = track as? any TrackSortDateProviding
            return .date(dateProvider?.trackSortDate)
        }
    }

    /// Убирает пробельные символы и превращает пустую строку в отсутствие значения.
    static func nonEmptyString(
        _ value: String?
    ) -> String? {
        let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue?.isEmpty == false ? trimmedValue : nil
    }
}

// MARK: - Comparison

private extension TrackSorter {
    /// Сравнивает ключи, оставляя отсутствующие значения в конце при любом направлении сортировки.
    static func compare(
        _ lhs: TrackSortKey,
        _ rhs: TrackSortKey,
        direction: TrackSortDirection
    ) -> ComparisonResult {
        switch (lhs, rhs) {
        case (.string(let leftValue), .string(let rightValue)):
            return compareOptionalValues(leftValue, rightValue, direction: direction) {
                compareStrings($0, $1)
            }
        case (.date(let leftValue), .date(let rightValue)):
            return compareOptionalValues(leftValue, rightValue, direction: direction) {
                compareDates($0, $1)
            }
        case (.number(let leftValue), .number(let rightValue)):
            return compareOptionalValues(leftValue, rightValue, direction: direction) {
                compareIntegers($0, $1)
            }
        default:
            // Разные типы ключей не должны встречаться для одного поля; сохраняем исходный порядок.
            return .orderedSame
        }
    }

    /// Сравнивает optional-значения и не меняет правило расположения пустых значений для descending.
    static func compareOptionalValues<Value>(
        _ lhs: Value?,
        _ rhs: Value?,
        direction: TrackSortDirection,
        compare: (Value, Value) -> ComparisonResult
    ) -> ComparisonResult {
        switch (lhs, rhs) {
        case (.none, .none):
            return .orderedSame
        case (.none, .some):
            return .orderedDescending
        case (.some, .none):
            return .orderedAscending
        case (.some(let leftValue), .some(let rightValue)):
            return oriented(compare(leftValue, rightValue), direction: direction)
        }
    }

    /// Применяет направление сортировки только к реально сравнимым значениям.
    static func oriented(
        _ result: ComparisonResult,
        direction: TrackSortDirection
    ) -> ComparisonResult {
        switch direction {
        case .ascending:
            return result
        case .descending:
            switch result {
            case .orderedAscending:
                return .orderedDescending
            case .orderedDescending:
                return .orderedAscending
            case .orderedSame:
                return .orderedSame
            }
        }
    }

    /// Сравнивает строки локализованно, без учёта регистра и диакритики.
    static func compareStrings(
        _ lhs: String,
        _ rhs: String
    ) -> ComparisonResult {
        lhs.compare(
            rhs,
            options: [.caseInsensitive, .diacriticInsensitive, .numeric],
            range: nil,
            locale: .current
        )
    }

    /// Сравнивает даты без допущений о семантике конкретного источника.
    static func compareDates(
        _ lhs: Date,
        _ rhs: Date
    ) -> ComparisonResult {
        if lhs < rhs { return .orderedAscending }
        if lhs > rhs { return .orderedDescending }
        return .orderedSame
    }

    /// Сравнивает целочисленные ключи без преобразования в строки.
    static func compareIntegers(
        _ lhs: Int,
        _ rhs: Int
    ) -> ComparisonResult {
        if lhs < rhs { return .orderedAscending }
        if lhs > rhs { return .orderedDescending }
        return .orderedSame
    }
}

/// Внутреннее представление значения, выбранного для сортировки.
private enum TrackSortKey {
    /// Строковый ключ для metadata-полей и имени файла.
    case string(String?)
    /// Числовой ключ для года выпуска.
    case number(Int?)
    /// Дата из отдельного date-контракта.
    case date(Date?)
}
