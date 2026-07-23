//
//  PurchasedITunesTrackSorter.swift
//  TrackList
//
//  Стабильная сортировка треков из системной медиатеки iOS.
//
//  Created by Pavel Fomin on 23.07.2026.
//

import Foundation

/// Сортирует модели MediaPlayer, не преобразуя их в обычные треки фонотеки.
enum PurchasedITunesTrackSorter {
    /// Возвращает новый массив и сохраняет исходный порядок только для полностью равных ключей.
    static func sort(
        _ tracks: [PurchasedITunesTrack],
        mode: PurchasedITunesTrackSortMode
    ) -> [PurchasedITunesTrack] {
        tracks
            .enumerated()
            .sorted { lhs, rhs in
                switch compare(lhs.element, rhs.element, mode: mode) {
                case .orderedAscending:
                    return true
                case .orderedDescending:
                    return false
                case .orderedSame:
                    // Индекс завершает стабильную сортировку, если даже persistentID совпали.
                    return lhs.offset < rhs.offset
                }
            }
            .map(\.element)
    }
}

// MARK: - Последовательность ключей

private extension PurchasedITunesTrackSorter {
    /// Сравнивает основное поле, канонические строковые ключи и стабильный persistentID.
    static func compare(
        _ lhs: PurchasedITunesTrack,
        _ rhs: PurchasedITunesTrack,
        mode: PurchasedITunesTrackSortMode
    ) -> ComparisonResult {
        let primaryResult = comparePrimaryField(lhs, rhs, mode: mode)
        guard primaryResult == .orderedSame else {
            return primaryResult
        }

        for field in fallbackStringFields(for: mode) {
            let result = TrackSorter.compareOptionalStrings(
                stringValue(for: lhs, field: field),
                stringValue(for: rhs, field: field),
                direction: .ascending
            )
            guard result == .orderedSame else {
                return result
            }
        }

        return TrackSorter.compareUnsignedIntegers(lhs.id, rhs.id)
    }

    /// Сравнивает выбранное пользователем поле в выбранном направлении.
    static func comparePrimaryField(
        _ lhs: PurchasedITunesTrack,
        _ rhs: PurchasedITunesTrack,
        mode: PurchasedITunesTrackSortMode
    ) -> ComparisonResult {
        switch mode {
        case .artistAsc:
            return compareStringField(lhs.artist, rhs.artist, direction: .ascending)
        case .artistDesc:
            return compareStringField(lhs.artist, rhs.artist, direction: .descending)
        case .titleAsc:
            return compareStringField(lhs.title, rhs.title, direction: .ascending)
        case .titleDesc:
            return compareStringField(lhs.title, rhs.title, direction: .descending)
        case .albumAsc:
            return compareStringField(lhs.album, rhs.album, direction: .ascending)
        case .albumDesc:
            return compareStringField(lhs.album, rhs.album, direction: .descending)
        case .yearDesc:
            return TrackSorter.compareOptionalIntegers(lhs.year, rhs.year, direction: .descending)
        case .yearAsc:
            return TrackSorter.compareOptionalIntegers(lhs.year, rhs.year, direction: .ascending)
        case .genreAsc:
            return compareStringField(lhs.genre, rhs.genre, direction: .ascending)
        case .genreDesc:
            return compareStringField(lhs.genre, rhs.genre, direction: .descending)
        case .dateAddedDesc:
            return TrackSorter.compareOptionalDates(lhs.dateAdded, rhs.dateAdded, direction: .descending)
        case .dateAddedAsc:
            return TrackSorter.compareOptionalDates(lhs.dateAdded, rhs.dateAdded, direction: .ascending)
        }
    }

    /// Переиспользует общий локализованный компаратор строк фонотеки.
    static func compareStringField(
        _ lhs: String?,
        _ rhs: String?,
        direction: TrackSortDirection
    ) -> ComparisonResult {
        TrackSorter.compareOptionalStrings(lhs, rhs, direction: direction)
    }

    /// Возвращает канонические запасные поля, исключая уже проверенное основное поле.
    static func fallbackStringFields(
        for mode: PurchasedITunesTrackSortMode
    ) -> [FallbackStringField] {
        let primaryField: FallbackStringField?

        switch mode {
        case .artistAsc, .artistDesc:
            primaryField = .artist
        case .titleAsc, .titleDesc:
            primaryField = .title
        case .albumAsc, .albumDesc:
            primaryField = .album
        case .yearDesc, .yearAsc,
             .genreAsc, .genreDesc,
             .dateAddedDesc, .dateAddedAsc:
            primaryField = nil
        }

        return FallbackStringField.allCases.filter { $0 != primaryField }
    }

    /// Извлекает строковое поле без связывания iTunes-модели с LibraryTrack.
    static func stringValue(
        for track: PurchasedITunesTrack,
        field: FallbackStringField
    ) -> String? {
        switch field {
        case .artist:
            return track.artist
        case .title:
            return track.title
        case .album:
            return track.album
        }
    }
}

/// Канонический порядок запасных строковых ключей.
private enum FallbackStringField: CaseIterable {
    case artist
    case title
    case album
}
