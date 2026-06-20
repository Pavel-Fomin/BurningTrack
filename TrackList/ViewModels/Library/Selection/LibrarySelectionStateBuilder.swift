//
//  LibrarySelectionStateBuilder.swift
//  TrackList
//
//  Собирает состояние выбора строк фонотеки.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

/// Собирает состояние выбора строк фонотеки.
/// Работает только с UI-идентификаторами строк: LibraryTrack.id.
struct LibrarySelectionStateBuilder {

    /// Возвращает UI-идентификаторы всех видимых строк в текущем порядке.
    func visibleRowIds(from sections: [TrackSection]) -> [UUID] {
        sections.flatMap { section in
            section.tracks.map { track in
                track.id
            }
        }
    }

    /// Проверяет, выбраны ли все видимые строки.
    func areAllVisibleRowsSelected(
        sections: [TrackSection],
        selection: OrderedSelection<UUID>
    ) -> Bool {
        let visibleRowIds = visibleRowIds(from: sections)
        return !visibleRowIds.isEmpty && selection.count == visibleRowIds.count
    }

    /// Возвращает доменные идентификаторы треков для выбранных UI-строк в порядке selection.
    func selectedTrackIds(
        selection: OrderedSelection<UUID>,
        sections: [TrackSection]
    ) -> [UUID] {
        let tracksByRowId = Dictionary(
            uniqueKeysWithValues: sections
                .flatMap { $0.tracks }
                .map { track in
                    (track.id, track)
                }
        )

        return selection.ids.compactMap { rowId in
            tracksByRowId[rowId]?.trackId
        }
    }
}
