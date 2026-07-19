//
//  TrackRuntimeSnapshotBuilding.swift
//  TrackList
//
//  Created by Pavel Fomin on 18.06.2026.
//

import Foundation

/// Создаёт runtime snapshot трека.
protocol TrackRuntimeSnapshotBuilding {
    /// Собирает runtime snapshot по идентификатору физического трека.
    func buildSnapshot(forTrackId trackId: UUID) async throws -> TrackRuntimeSnapshot?
}
