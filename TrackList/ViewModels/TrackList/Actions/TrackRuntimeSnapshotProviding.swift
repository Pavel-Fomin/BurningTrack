//
//  TrackRuntimeSnapshotProviding.swift
//  TrackList
//
//  Объявляет read-only доступ к уже подготовленным runtime-снимкам треков.
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

/// Предоставляет read/write доступ к runtime snapshot-ам для controller-ов,
/// которые после успешной асинхронной сборки фиксируют новый снимок в общем store.
@MainActor
protocol TrackRuntimeSnapshotStoring: TrackRuntimeSnapshotProviding {
    /// Сохраняет каноничный runtime snapshot трека.
    func storeSnapshot(_ snapshot: TrackRuntimeSnapshot)
}
