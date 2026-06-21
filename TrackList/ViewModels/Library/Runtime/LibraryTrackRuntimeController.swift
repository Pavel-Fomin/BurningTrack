//
//  LibraryTrackRuntimeController.swift
//  TrackList
//
//  Контроллер runtime snapshot-ов фонотеки.
//  Отделяет runtime pipeline от LibraryTracksViewModel.
//
//  Created by Pavel Fomin on 21.06.2026.
//

import Combine
import Foundation

/// Управляет runtime snapshot-ами, которые нужны модулю фонотеки.
///
/// Отвечает только за:
/// - хранение snapshot-ов по trackId;
/// - загрузку snapshot из TrackRuntimeStore или TrackRuntimeSnapshotBuilder;
/// - сохранение собранного snapshot в TrackRuntimeStore;
/// - применение готовых TrackUpdateEvent к локальному состоянию.
///
/// Не знает про UI, View, batch-сценарии, NotificationCenter, Player и badges.
@MainActor
final class LibraryTrackRuntimeController: ObservableObject {

    // MARK: - State

    @Published private(set) var snapshotsByTrackId: [UUID: TrackRuntimeSnapshot] = [:]

    // MARK: - Init

    /// Позволяет создавать controller как зависимость по умолчанию.
    nonisolated init() {}

    // MARK: - Public

    /// Возвращает runtime snapshot трека по его идентификатору.
    ///
    /// - Parameter trackId: Идентификатор трека
    /// - Returns: TrackRuntimeSnapshot или nil
    func snapshot(for trackId: UUID) -> TrackRuntimeSnapshot? {
        snapshotsByTrackId[trackId]
    }

    /// Запрашивает runtime snapshot трека, если он ещё не загружен.
    ///
    /// - Parameter trackId: Идентификатор трека
    func requestSnapshotIfNeeded(for trackId: UUID) {
        Task { [weak self] in
            guard let self else { return }

            await self.loadSnapshotIfNeeded(for: trackId)
        }
    }

    // MARK: - Internal

    /// Загружает runtime snapshot и возвращает результат сценариям, которым нужно дождаться metadata.
    ///
    /// - Parameter trackId: Идентификатор трека
    /// - Returns: Загруженный TrackRuntimeSnapshot или nil
    @discardableResult
    func loadSnapshotIfNeeded(for trackId: UUID) async -> TrackRuntimeSnapshot? {
        if let existingSnapshot = snapshotsByTrackId[trackId] {
            return existingSnapshot
        }

        let snapshot: TrackRuntimeSnapshot?

        // Сначала используем общий runtime store как быстрый источник уже собранного snapshot.
        if let storedSnapshot = TrackRuntimeStore.shared.snapshot(forTrackId: trackId) {
            snapshot = storedSnapshot
        } else {
            snapshot = await TrackRuntimeSnapshotBuilder.shared.buildSnapshot(forTrackId: trackId)

            // Новый snapshot сразу фиксируем в общем runtime store.
            if let snapshot {
                TrackRuntimeStore.shared.storeSnapshot(snapshot)
            }
        }

        guard let snapshot else {
            return nil
        }

        snapshotsByTrackId[trackId] = snapshot

        return snapshot
    }

    /// Применяет готовые события обновления треков к локальному состоянию snapshot-ов.
    ///
    /// - Parameter events: События с уже собранными runtime snapshot
    func applyTrackUpdateEvents(_ events: [TrackUpdateEvent]) {
        guard !events.isEmpty else { return }

        var updatedSnapshots = snapshotsByTrackId

        for event in events {
            updatedSnapshots[event.trackId] = event.snapshot
        }

        snapshotsByTrackId = updatedSnapshots
    }

    /// Очищает локальные snapshot-ы фонотеки.
    func clearSnapshots() {
        snapshotsByTrackId.removeAll()
    }
}
