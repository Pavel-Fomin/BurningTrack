//
//  TrackRuntimeStore.swift
//  TrackList
//
//  Централизованное runtime-хранилище актуальных snapshot треков.
//  Роль:
//  - хранит последние собранные TrackRuntimeSnapshot по trackId
//  - отдаёт snapshot без повторного чтения файла
//  - не читает файл сам
//  - не публикует события
//
//  Created by PavelFomin on 24.04.2026.
//

import Foundation

final class TrackRuntimeStore {

    // MARK: - Singleton

    static let shared = TrackRuntimeStore()  /// Общий экземпляр runtime-хранилища snapshot

    // MARK: - Storage

    private var snapshotsByTrackId: [UUID: TrackRuntimeSnapshot] = [:]  /// Словарь актуальных snapshot по идентификатору трека

    // MARK: - Init

    private init() {}

    // MARK: - Read

    /// Возвращает сохранённый snapshot трека по его идентификатору.
    ///
    /// - Parameter trackId: Идентификатор трека
    /// - Returns: Сохранённый TrackRuntimeSnapshot или nil, если snapshot ещё не был сохранён
    func snapshot(forTrackId trackId: UUID) -> TrackRuntimeSnapshot? {
        snapshotsByTrackId[trackId]
    }

    // MARK: - Write

    /// Сохраняет или обновляет snapshot трека в runtime-хранилище.
    ///
    /// - Parameter snapshot: Актуальный snapshot трека
    func storeSnapshot(_ snapshot: TrackRuntimeSnapshot) {
        snapshotsByTrackId[snapshot.trackId] = snapshot
    }

    // MARK: - Remove

    /// Удаляет snapshot одного трека из runtime-хранилища.
    ///
    /// - Parameter trackId: Идентификатор трека
    func removeSnapshot(forTrackId trackId: UUID) {
        snapshotsByTrackId.removeValue(forKey: trackId)
    }

    /// Полностью очищает runtime-хранилище snapshot.
    func removeAllSnapshots() {
        snapshotsByTrackId.removeAll()
    }
}
