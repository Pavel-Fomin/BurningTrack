//
//  TrackListsOrderingPersisting.swift
//  TrackList
//
//  Контракт атомарного сохранения порядка и режима сортировки.
//
//  Created by Pavel Fomin on 13.08.2026.
//

import Foundation

/// Сохраняет единую пользовательскую команду порядка без расхождения SQLite-настроек и списка.
protocol TrackListsOrderingPersisting {

    /// Атомарно сохраняет полный отображаемый порядок и связанный с ним режим сортировки.
    func persist(
        sortMode: TrackListsSortMode?,
        orderedTrackListIDs: [UUID]
    ) throws
}
