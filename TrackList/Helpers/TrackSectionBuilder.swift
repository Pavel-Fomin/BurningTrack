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
    case flat
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
        case .flat:
            return makeFlatSection(tracks)
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
        let dateFormatter = DateFormatter()
        // Заголовки date-секций используют базовую английскую локаль приложения.
        dateFormatter.locale = Locale(identifier: "en")
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        var sections: [(day: Date, tracks: [LibraryTrack])] = []
        var sectionIndexByDay: [Date: Int] = [:]

        for track in tracks {
            let day = calendar.startOfDay(for: track.addedDate)

            if let sectionIndex = sectionIndexByDay[day] {
                sections[sectionIndex].tracks.append(track)
            } else {
                sectionIndexByDay[day] = sections.count
                sections.append((day: day, tracks: [track]))
            }
        }

        return sections.map { section in
            TrackSection(
                id: section.day.iso8601String,
                title: title(
                    for: section.day,
                    calendar: calendar,
                    dateFormatter: dateFormatter
                ),
                tracks: section.tracks
            )
        }
    }

    /// Создаёт одну секцию без заголовка для глобальной сортировки по metadata-полям.
    static func makeFlatSection(
        _ tracks: [LibraryTrack]
    ) -> [TrackSection] {
        guard tracks.isEmpty == false else { return [] }

        return [
            TrackSection(
                id: "library-tracks-flat-section",
                title: "",
                tracks: tracks,
                showsHeader: false
            )
        ]
    }

    /// Возвращает человекочитаемый заголовок date-секции.
    static func title(
        for day: Date,
        calendar: Calendar,
        dateFormatter: DateFormatter
    ) -> String {
        if calendar.isDateInToday(day) { return String(localized: "Today") }
        if calendar.isDateInYesterday(day) { return String(localized: "Yesterday") }
        return dateFormatter.string(from: day)
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
        return artist?.isEmpty == false ? artist! : String(localized: "Unknown Artist")
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
