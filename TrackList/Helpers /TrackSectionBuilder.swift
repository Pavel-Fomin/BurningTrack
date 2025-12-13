//
//  TrackSectionBuilder.swift
//  TrackList
//
//  Подготовка TrackSection для UI.
//  Группирует треки по выбранному режиму
//
//  Created by Pavel Fomin on 13.12.2025.
//

import Foundation

// MARK: - Grouping mode

enum TrackGroupingMode {
    case date
    case artist
    case title
}

// MARK: - Builder

struct TrackSectionBuilder {

    static func build(
        from tracks: [LibraryTrack],
        mode: TrackGroupingMode
    ) -> [TrackSection] {

        switch mode {
        case .date:
            return groupByDate(tracks)
        case .artist:
            return groupByArtist(tracks)
        case .title:
            return groupByTitle(tracks)
        }
    }
}

// MARK: - Date grouping

private extension TrackSectionBuilder {

    static func groupByDate(
        _ tracks: [LibraryTrack]
    ) -> [TrackSection] {

        let calendar = Calendar.current

        let grouped = Dictionary(grouping: tracks) {
            calendar.startOfDay(for: $0.addedDate)
        }

        let sortedDays = grouped.keys.sorted(by: >)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        return sortedDays.map { day in
            let title: String = {
                if calendar.isDateInToday(day) { return "Сегодня" }
                if calendar.isDateInYesterday(day) { return "Вчера" }
                return dateFormatter.string(from: day)
            }()

            let items = (grouped[day] ?? []).sorted {
                ($0.addedDate, $0.fileName) > ($1.addedDate, $1.fileName)
            }

            return TrackSection(
                id: day.iso8601String,
                title: title,
                tracks: items
            )
        }
    }
}

// MARK: - Artist grouping

private extension TrackSectionBuilder {

    static func groupByArtist(
        _ tracks: [LibraryTrack]
    ) -> [TrackSection] {

        let grouped = Dictionary(grouping: tracks) {
            normalizedArtist($0)
        }

        let sortedKeys = grouped.keys.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        return sortedKeys.map { artist in
            let items = (grouped[artist] ?? []).sorted {
                normalizedTitle($0)
                    .localizedCaseInsensitiveCompare(normalizedTitle($1)) == .orderedAscending
            }

            return TrackSection(
                id: artist,
                title: artist,
                tracks: items
            )
        }
    }
}

// MARK: - Title grouping

private extension TrackSectionBuilder {

    static func groupByTitle(
        _ tracks: [LibraryTrack]
    ) -> [TrackSection] {

        let grouped = Dictionary(grouping: tracks) {
            let title = normalizedTitle($0)
            return String(title.prefix(1)).uppercased()
        }

        let sortedKeys = grouped.keys.sorted()

        return sortedKeys.map { letter in
            let items = (grouped[letter] ?? []).sorted {
                normalizedTitle($0)
                    .localizedCaseInsensitiveCompare(normalizedTitle($1)) == .orderedAscending
            }

            return TrackSection(
                id: letter,
                title: letter,
                tracks: items
            )
        }
    }
}

// MARK: - Normalization helpers

private extension TrackSectionBuilder {

    static func normalizedArtist(_ track: LibraryTrack) -> String {
        let artist = track.artist?.trimmingCharacters(in: .whitespacesAndNewlines)
        return artist?.isEmpty == false ? artist! : "Неизвестный артист"
    }

    static func normalizedTitle(_ track: LibraryTrack) -> String {
        let title = track.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return title?.isEmpty == false ? title! : track.fileName
    }
}

// MARK: - Date helper

private extension Date {

    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}
