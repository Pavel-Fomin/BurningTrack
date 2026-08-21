//
//  TrackRuntimeSnapshotBuilding.swift
//  TrackList
//
//  Объявляет асинхронное построение runtime-снимка по физическому идентификатору трека.
//
//  Created by Pavel Fomin on 18.06.2026.
//

import Foundation

/// Создаёт runtime snapshot трека из Sendable идентификатора без screen-local mutable state.
protocol TrackRuntimeSnapshotBuilding: Sendable {
    /// Собирает runtime snapshot по идентификатору физического трека.
    func buildSnapshot(forTrackId trackId: UUID) async throws -> TrackRuntimeSnapshot?
}
