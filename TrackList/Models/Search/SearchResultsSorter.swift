//
//  SearchResultsSorter.swift
//  TrackList
//
//  Сортировка отображаемых результатов поиска.
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

// Сортирует только видимые результаты поиска, не меняя исходный каталог треков.
struct SearchResultsSorter {
    /// Возвращает новый массив треков в порядке выбранного режима сортировки.
    static func sort(
        _ tracks: [SearchTrackResult],
        using mode: SearchSortMode
    ) -> [SearchTrackResult] {
        tracks
            .enumerated()
            .sorted { lhs, rhs in
                let leftKey = key(for: lhs.element, mode: mode)
                let rightKey = key(for: rhs.element, mode: mode)
                let primaryComparison = compare(
                    leftKey,
                    rightKey,
                    direction: direction(for: mode)
                )

                if primaryComparison != .orderedSame {
                    return primaryComparison == .orderedAscending
                }

                if mode.isTagSortMode {
                    return lhs.offset < rhs.offset
                }

                let fallbackComparison = compareFallback(lhs.element, rhs.element)
                if fallbackComparison != .orderedSame {
                    return fallbackComparison == .orderedAscending
                }

                return lhs.offset < rhs.offset
            }
            .map { $0.element }
    }
}

private extension SearchResultsSorter {
    /// Собирает основной ключ сортировки из уже доступных данных результата поиска.
    static func key(
        for track: SearchTrackResult,
        mode: SearchSortMode
    ) -> SearchSortKey {
        switch mode {
        case .artistAsc,
             .artistDesc:
            return .string(nonEmpty(track.artist))

        case .titleAsc,
             .titleDesc:
            return .string(nonEmpty(track.title))

        case .albumAsc,
             .albumDesc:
            return .string(nonEmpty(track.album))

        case .yearNewest,
             .yearOldest:
            return .number(track.year)

        case .labelAsc,
             .labelDesc:
            return .string(nonEmpty(track.label))

        case .genreAsc,
             .genreDesc:
            return .string(nonEmpty(track.genre))

        case .commentAsc:
            return .string(nonEmpty(track.comment))

        case .filenameAsc,
             .filenameDesc:
            return .string(nonEmpty(track.fileName))

        case .dateNewest,
             .dateOldest:
            return .date(track.fileDate)
        }
    }

    /// Определяет направление сортировки без привязки к тексту пункта меню.
    static func direction(for mode: SearchSortMode) -> SearchSortDirection {
        switch mode {
        case .artistAsc,
             .titleAsc,
             .albumAsc,
             .yearOldest,
             .labelAsc,
             .genreAsc,
             .commentAsc,
             .filenameAsc,
             .dateOldest:
            return .ascending

        case .artistDesc,
             .titleDesc,
             .albumDesc,
             .yearNewest,
             .labelDesc,
             .genreDesc,
             .filenameDesc,
             .dateNewest:
            return .descending
        }
    }

    /// Вторичный fallback сохраняет прежнее детерминированное упорядочивание.
    static func compareFallback(
        _ lhs: SearchTrackResult,
        _ rhs: SearchTrackResult
    ) -> ComparisonResult {
        let comparisons: [ComparisonResult] = [
            compareStrings(nonEmpty(lhs.artist), nonEmpty(rhs.artist)),
            compareStrings(nonEmpty(lhs.title), nonEmpty(rhs.title)),
            compareStrings(nonEmpty(lhs.album), nonEmpty(rhs.album)),
            compareStrings(nonEmpty(lhs.fileName), nonEmpty(rhs.fileName)),
            compareStrings(nonEmpty(lhs.relativePath), nonEmpty(rhs.relativePath))
        ]

        if let comparison = comparisons.first(where: { $0 != .orderedSame }) {
            return comparison
        }

        return compareStrings(lhs.id.uuidString, rhs.id.uuidString)
    }

    /// Сравнивает однотипные ключи сортировки и оставляет пустые значения внизу.
    static func compare(
        _ lhs: SearchSortKey,
        _ rhs: SearchSortKey,
        direction: SearchSortDirection
    ) -> ComparisonResult {
        switch (lhs, rhs) {
        case (.string(let leftValue), .string(let rightValue)):
            return compareOptionalValues(leftValue, rightValue, direction: direction) {
                compareStrings($0, $1)
            }

        case (.number(let leftValue), .number(let rightValue)):
            return compareOptionalValues(leftValue, rightValue, direction: direction) {
                compareIntegers($0, $1)
            }

        case (.date(let leftValue), .date(let rightValue)):
            return compareOptionalValues(leftValue, rightValue, direction: direction) {
                compareDates($0, $1)
            }

        default:
            return .orderedSame
        }
    }

    /// Сравнивает optional-значения, не разворачивая порядок пустых значений для descending.
    static func compareOptionalValues<Value>(
        _ lhs: Value?,
        _ rhs: Value?,
        direction: SearchSortDirection,
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

    /// Применяет направление только к непустым значениям.
    static func oriented(
        _ result: ComparisonResult,
        direction: SearchSortDirection
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

    /// Локализованно сравнивает строки так же, как пользователь ожидает в списке треков.
    static func compareStrings(
        _ lhs: String?,
        _ rhs: String?
    ) -> ComparisonResult {
        compareOptionalValues(lhs, rhs, direction: .ascending) {
            $0.compare(
                $1,
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive, .numeric],
                range: nil,
                locale: .current
            )
        }
    }

    /// Сравнивает годы как числа, а не как строки.
    static func compareIntegers(
        _ lhs: Int,
        _ rhs: Int
    ) -> ComparisonResult {
        if lhs < rhs { return .orderedAscending }
        if lhs > rhs { return .orderedDescending }
        return .orderedSame
    }

    /// Сравнивает даты без допущений о часовом поясе или формате.
    static func compareDates(
        _ lhs: Date,
        _ rhs: Date
    ) -> ComparisonResult {
        if lhs < rhs { return .orderedAscending }
        if lhs > rhs { return .orderedDescending }
        return .orderedSame
    }

    /// Убирает пробельные значения, чтобы они уходили вниз как отсутствующие.
    static func nonEmpty(_ value: String?) -> String? {
        let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue?.isEmpty == false ? trimmedValue : nil
    }
}

// Значение ключа сортировки поиска.
private enum SearchSortKey {
    case string(String?)
    case number(Int?)
    case date(Date?)
}

private extension SearchSortMode {
    /// Признак теговой сортировки нужен, чтобы при равных тегах сохранять исходный порядок.
    var isTagSortMode: Bool {
        switch self {
        case .artistAsc,
             .artistDesc,
             .titleAsc,
             .titleDesc,
             .albumAsc,
             .albumDesc,
             .yearNewest,
             .yearOldest,
             .labelAsc,
             .labelDesc,
             .genreAsc,
             .genreDesc,
             .commentAsc:
            return true

        case .filenameAsc,
             .filenameDesc,
             .dateNewest,
             .dateOldest:
            return false
        }
    }
}

// Направление сортировки поиска.
private enum SearchSortDirection {
    case ascending
    case descending
}
