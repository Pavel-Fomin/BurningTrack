//
//  LibraryTrackOrdering.swift
//  TrackList
//
//  Общий порядок треков фонотеки для UI и восстановления playback-контекста.
//
//  Created by Pavel Fomin on 15.07.2026.
//

import Foundation

/// Применяет к фонотеке тот же стабильный порядок, который использует список треков.
enum LibraryTrackOrdering {
    /// Сортирует треки по выбранному режиму и SQLite metadata.
    static func sort(
        _ tracks: [LibraryTrack],
        mode: LibraryTrackSortMode,
        cachedMetadataByTrackId: [UUID: TrackCachedMetadata]
    ) -> [LibraryTrack] {
        let adapters = tracks.map { track in
            LibraryTrackSortAdapter(
                track: track,
                cachedMetadata: cachedMetadataByTrackId[track.trackId]
            )
        }

        return TrackSorter
            .sort(adapters, using: mode.descriptor)
            .map(\.track)
    }
}

/// Даёт TrackSorter сортировочные значения фонотеки без записи metadata обратно в LibraryTrack.
struct LibraryTrackSortAdapter: TrackDisplayable, TrackSortDateProviding, TrackSortMetadataProviding {
    let track: LibraryTrack
    let cachedMetadata: TrackCachedMetadata?

    var id: UUID {
        track.id
    }

    var trackId: UUID {
        track.trackId
    }

    var fileName: String {
        track.fileName
    }

    /// Для сортировки title используются только сохранённые metadata без fallback на имя файла.
    var title: String? {
        Self.nonEmptyString(cachedMetadata?.title)
    }

    /// Для сортировки artist используются только сохранённые metadata без fallback на имя файла.
    var artist: String? {
        Self.nonEmptyString(cachedMetadata?.artist)
    }

    /// Для сортировки album используются только сохранённые metadata без fallback на имя файла.
    var trackSortAlbum: String? {
        Self.nonEmptyString(cachedMetadata?.album)
    }

    /// Для сортировки year fallback на fileName не применяется.
    var trackSortYear: Int? {
        cachedMetadata?.year
    }

    /// Для сортировки label используются только сохранённые metadata без fallback на имя файла.
    var trackSortLabel: String? {
        Self.nonEmptyString(cachedMetadata?.label)
    }

    /// Для сортировки genre используются только сохранённые metadata без fallback на имя файла.
    var trackSortGenre: String? {
        Self.nonEmptyString(cachedMetadata?.genre)
    }

    /// Для сортировки comment используются только сохранённые metadata без fallback на имя файла.
    var trackSortComment: String? {
        Self.nonEmptyString(cachedMetadata?.comment)
    }

    var duration: Double {
        track.duration
    }

    var isAvailable: Bool {
        track.isAvailable
    }

    /// Дата сортировки остаётся датой фонотеки из исходного LibraryTrack.
    var trackSortDate: Date? {
        track.trackSortDate
    }

    /// Пустые строки из SQLite не участвуют в сортировке как самостоятельное значение.
    private static func nonEmptyString(_ value: String?) -> String? {
        let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue?.isEmpty == false ? trimmedValue : nil
    }
}
