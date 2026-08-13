//
//  TrackCollectionMetadataLoading.swift
//  TrackList
//
//  Узкое чтение сохранённых metadata для переходов из detail-треклиста.
//
//  Created by Pavel Fomin on 13.08.2026.
//

import Foundation

/// Загружает сохранённые metadata локальных треков без раскрытия concrete TrackRegistry в feature.
protocol TrackCollectionMetadataLoading: Sendable {
    /// Возвращает metadata только для запрошенных физических идентификаторов треков.
    func cachedMetadata(forTrackIds trackIds: [UUID]) async -> [UUID: TrackCachedMetadata]
}

extension TrackRegistry: TrackCollectionMetadataLoading {}
