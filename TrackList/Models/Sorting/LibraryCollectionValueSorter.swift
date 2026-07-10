//
//  LibraryCollectionValueSorter.swift
//  TrackList
//
//  Сортировщик значений разделов музыкальной коллекции.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

/// Сортирует значения разделов музыкальной коллекции.
struct LibraryCollectionValueSorter {
    /// Возвращает новый массив значений в выбранном порядке.
    static func sort(
        _ values: [LibraryCollectionValue],
        mode: LibraryCollectionValueSortMode
    ) -> [LibraryCollectionValue] {
        values.sorted { left, right in
            switch mode {
            case .titleAscending:
                return compareTitle(left, right, direction: .ascending) == .orderedAscending
            case .titleDescending:
                return compareTitle(left, right, direction: .descending) == .orderedAscending
            case .yearNewestFirst:
                return compareYear(left, right, direction: .descending) == .orderedAscending
            case .yearOldestFirst:
                return compareYear(left, right, direction: .ascending) == .orderedAscending
            case .artistAscending:
                return compareArtist(left, right, direction: .ascending) == .orderedAscending
            case .artistDescending:
                return compareArtist(left, right, direction: .descending) == .orderedAscending
            }
        }
    }
}

private extension LibraryCollectionValueSorter {
    /// Направление основного поля сортировки; дополнительные поля всегда идут по возрастанию.
    enum Direction {
        /// Возрастание основного поля.
        case ascending
        /// Убывание основного поля.
        case descending
    }

    /// Сравнивает значения по названию, артисту, году и идентификатору.
    static func compareTitle(
        _ left: LibraryCollectionValue,
        _ right: LibraryCollectionValue,
        direction: Direction
    ) -> ComparisonResult {
        comparePrimary(
            primary: compareStrings(left.title, right.title),
            direction: direction,
            additional: [
                compareOptionalStrings(left.artist, right.artist),
                compareOptionalIntegers(left.year, right.year),
                compareStrings(left.id, right.id)
            ]
        )
    }

    /// Сравнивает значения по году с обязательным размещением пустого года в конце.
    static func compareYear(
        _ left: LibraryCollectionValue,
        _ right: LibraryCollectionValue,
        direction: Direction
    ) -> ComparisonResult {
        compareOptionalPrimary(
            left: yearValue(for: left),
            right: yearValue(for: right),
            direction: direction,
            compare: compareIntegers,
            additional: [
                compareStrings(left.title, right.title),
                compareOptionalStrings(left.artist, right.artist),
                compareStrings(left.id, right.id)
            ]
        )
    }

    /// Сравнивает значения по артисту с обязательным размещением пустого артиста в конце.
    static func compareArtist(
        _ left: LibraryCollectionValue,
        _ right: LibraryCollectionValue,
        direction: Direction
    ) -> ComparisonResult {
        compareOptionalPrimary(
            left: left.artist,
            right: right.artist,
            direction: direction,
            compare: compareStrings,
            additional: [
                compareStrings(left.title, right.title),
                compareOptionalIntegers(left.year, right.year),
                compareStrings(left.id, right.id)
            ]
        )
    }

    /// Выбирает первый ненулевой результат сравнения, меняя направление только для основного поля.
    static func comparePrimary(
        primary: ComparisonResult,
        direction: Direction,
        additional: [ComparisonResult]
    ) -> ComparisonResult {
        if primary != .orderedSame {
            switch direction {
            case .ascending:
                return primary
            case .descending:
                return reversed(primary)
            }
        }

        for result in additional where result != .orderedSame {
            return result
        }

        return .orderedSame
    }

    /// Сравнивает необязательное основное поле, оставляя отсутствующие значения в конце при любом направлении.
    static func compareOptionalPrimary<Value>(
        left: Value?,
        right: Value?,
        direction: Direction,
        compare: (Value, Value) -> ComparisonResult,
        additional: [ComparisonResult]
    ) -> ComparisonResult {
        switch (left, right) {
        case let (left?, right?):
            return comparePrimary(
                primary: compare(left, right),
                direction: direction,
                additional: additional
            )
        case (nil, nil):
            for result in additional where result != .orderedSame {
                return result
            }
            return .orderedSame
        case (nil, _?):
            return .orderedDescending
        case (_?, nil):
            return .orderedAscending
        }
    }

    /// Сравнивает строки в том же пользовательском порядке, который используется в списках приложения.
    static func compareStrings(_ left: String, _ right: String) -> ComparisonResult {
        left.localizedStandardCompare(right)
    }

    /// Сравнивает необязательные строки, помещая отсутствующие значения после заполненных.
    static func compareOptionalStrings(_ left: String?, _ right: String?) -> ComparisonResult {
        switch (left, right) {
        case let (left?, right?):
            return compareStrings(left, right)
        case (nil, nil):
            return .orderedSame
        case (nil, _?):
            return .orderedDescending
        case (_?, nil):
            return .orderedAscending
        }
    }

    /// Сравнивает необязательные числа, помещая отсутствующие значения после заполненных.
    static func compareOptionalIntegers(_ left: Int?, _ right: Int?) -> ComparisonResult {
        switch (left, right) {
        case let (left?, right?):
            return compareIntegers(left, right)
        case (nil, nil):
            return .orderedSame
        case (nil, _?):
            return .orderedDescending
        case (_?, nil):
            return .orderedAscending
        }
    }

    /// Сравнивает два числовых значения без преобразования в строки.
    static func compareIntegers(_ left: Int, _ right: Int) -> ComparisonResult {
        if left < right { return .orderedAscending }
        if left > right { return .orderedDescending }
        return .orderedSame
    }

    /// Возвращает числовой год из модели или rawValue для значений раздела годов.
    static func yearValue(for value: LibraryCollectionValue) -> Int? {
        if value.category == .years {
            return Int(value.rawValue.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return value.year
    }

    /// Меняет направление результата сравнения для основного поля.
    static func reversed(_ result: ComparisonResult) -> ComparisonResult {
        switch result {
        case .orderedAscending:
            return .orderedDescending
        case .orderedDescending:
            return .orderedAscending
        case .orderedSame:
            return .orderedSame
        @unknown default:
            return .orderedSame
        }
    }
}
