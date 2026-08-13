//
//  TrackListReading.swift
//  TrackList
//
//  Created by Pavel Fomin on 18.06.2026.
//

import Foundation

/// Предоставляет данные одного треклиста для action handlers.
@MainActor
protocol TrackListReading {
    /// Идентификатор текущего треклиста.
    var trackListId: UUID { get }

    /// Название текущего треклиста.
    var name: String { get }

    /// Текущие треки треклиста.
    var tracks: [Track] { get }

    /// Возвращает строку по её row identity без смешивания с physical trackId.
    func track(forRowId rowId: UUID) -> Track?

    /// Возвращает уже подготовленный target перехода к артисту или альбому.
    func collectionNavigationTarget(forRowId rowId: UUID) -> TrackCollectionNavigationTarget?

    /// Возвращает последний runtime snapshot, если он уже подготовлен для строки.
    func runtimeSnapshot(forTrackId trackId: UUID) -> TrackRuntimeSnapshot?

    /// Запрашивает lifecycle-managed runtime snapshot для видимой строки.
    func requestSnapshotIfNeeded(for trackId: UUID)
}

extension TrackListReading {

    /// Находит строку стандартным образом, если отдельный reader не хранит индекс.
    func track(forRowId rowId: UUID) -> Track? {
        tracks.first { $0.id == rowId }
    }

    /// По умолчанию reader не обязан предоставлять навигационные metadata.
    func collectionNavigationTarget(forRowId rowId: UUID) -> TrackCollectionNavigationTarget? {
        nil
    }

    /// По умолчанию reader не обязан хранить runtime snapshot.
    func runtimeSnapshot(forTrackId trackId: UUID) -> TrackRuntimeSnapshot? {
        nil
    }

    /// Неподдерживающий runtime reader не запускает file loading.
    func requestSnapshotIfNeeded(for trackId: UUID) {}
}
