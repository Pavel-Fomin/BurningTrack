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
                header: .date(section.day),
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
                header: .hidden,
                tracks: tracks
            )
        ]
    }
}

// MARK: - Artist grouping

private extension TrackSectionBuilder {

    static func groupByArtist(
        _ tracks: [LibraryTrack]
    ) -> [TrackSection] {

        let grouped = Dictionary(grouping: tracks, by: artistGroup)

        let sortedKeys = grouped.keys.sorted {
            $0.sortValue.localizedCaseInsensitiveCompare($1.sortValue) == .orderedAscending
        }

        return sortedKeys.map { group in
            let items = (grouped[group] ?? []).sorted {
                normalizedTitle($0)
                    .localizedCaseInsensitiveCompare(normalizedTitle($1)) == .orderedAscending
            }

            return TrackSection(
                id: group.id,
                header: group.header,
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
                header: .metadata(letter),
                tracks: items
            )
        }
    }
}

// MARK: - Normalization helpers

private extension TrackSectionBuilder {

    /// Формирует технический ключ группировки, не подменяя отсутствующего исполнителя готовым текстом.
    static func artistGroup(_ track: LibraryTrack) -> ArtistGroup {
        let artist = track.artist?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let artist, artist.isEmpty == false else {
            return ArtistGroup(
                id: "artist:missing",
                sortValue: "\u{FFFF}",
                header: .unknownArtist
            )
        }

        return ArtistGroup(
            id: "artist:\(artist)",
            sortValue: artist,
            header: .metadata(artist)
        )
    }

    static func normalizedTitle(_ track: LibraryTrack) -> String {
        let title = track.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return title?.isEmpty == false ? title! : track.fileName
    }
}

private extension TrackSectionBuilder {

    /// Сохраняет устойчивый ключ и порядок группировки отдельно от подписи интерфейса.
    struct ArtistGroup: Hashable {
        let id: String
        let sortValue: String
        let header: TrackSectionHeader
    }
}

// MARK: - Date helper

private extension Date {

    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}
