//
//  TrackRuntimeSnapshotProviding.swift
//  TrackList
//
//  Created by Pavel Fomin on 18.06.2026.
//

import Foundation

/// Предоставляет уже сохранённый runtime snapshot трека.
@MainActor
protocol TrackRuntimeSnapshotProviding {
    /// Возвращает runtime snapshot по идентификатору физического трека.
    func snapshot(forTrackId trackId: UUID) -> TrackRuntimeSnapshot?
}
