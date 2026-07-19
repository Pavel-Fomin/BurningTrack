//
//  BatchTagMetadataLoader.swift
//  TrackList
//
//  Loader metadata для массового редактирования тегов.
//
//  Created by Pavel Fomin on 27.05.2026.
//

import Foundation

/// Loader metadata для массового редактирования тегов.
///
/// Роль:
/// - получает runtime snapshots для выбранных треков;
/// - сначала проверяет TrackRuntimeStore;
/// - если snapshot отсутствует, строит его через TrackRuntimeSnapshotBuilder;
/// - собирает BatchTagEditFlow через BatchTagEditFlowBuilder;
/// - не знает про UI, SheetManager и сохранение тегов.
struct BatchTagMetadataLoader {
    /// Хранилище runtime snapshots.
    private let runtimeStore: TrackRuntimeStore
    /// Builder runtime snapshot.
    private let snapshotBuilder: TrackRuntimeSnapshotBuilder
    /// Ограничение параллельной загрузки snapshot.
    private let limiter: BatchTagMetadataAsyncLimiter

    @MainActor
    init(concurrentLimit: Int = 6) {
        self.runtimeStore = .shared
        self.snapshotBuilder = .shared
        self.limiter = BatchTagMetadataAsyncLimiter(limit: concurrentLimit)
    }

    init(
        runtimeStore: TrackRuntimeStore,
        snapshotBuilder: TrackRuntimeSnapshotBuilder = .shared,
        concurrentLimit: Int = 6
    ) {
        self.runtimeStore = runtimeStore
        self.snapshotBuilder = snapshotBuilder
        self.limiter = BatchTagMetadataAsyncLimiter(limit: concurrentLimit)
    }

    /// Загружает metadata и возвращает готовый flow массового редактирования тегов.
    func loadFlow(
        pendingAction: PendingBulkTrackAction
    ) async -> BatchTagEditFlow {
        let snapshots = await loadSnapshots(trackIDs: pendingAction.trackIDs)
        return BatchTagEditFlowBuilder.makeFlow(
            pendingAction: pendingAction,
            snapshots: snapshots
        )
    }

    /// Загружает snapshots для выбранных треков.
    private func loadSnapshots(trackIDs: [UUID]) async -> [TrackRuntimeSnapshot] {
        let runtimeStore = runtimeStore
        let snapshotBuilder = snapshotBuilder
        let limiter = limiter

        return await withTaskGroup(of: TrackRuntimeSnapshot?.self) { group in
            for trackID in trackIDs {
                group.addTask {
                    await limiter.acquire()
                    defer {
                        Task {
                            await limiter.release()
                        }
                    }
                    return await loadSnapshot(
                        trackID: trackID,
                        runtimeStore: runtimeStore,
                        snapshotBuilder: snapshotBuilder
                    )
                }
            }

            var snapshots: [TrackRuntimeSnapshot] = []
            for await snapshot in group {
                if let snapshot {
                    snapshots.append(snapshot)
                }
            }
            return snapshots
        }
    }

    /// Загружает snapshot одного трека.
    private func loadSnapshot(
        trackID: UUID,
        runtimeStore: TrackRuntimeStore,
        snapshotBuilder: TrackRuntimeSnapshotBuilder
    ) async -> TrackRuntimeSnapshot? {
        if let storedSnapshot = await runtimeStore.snapshot(forTrackId: trackID) {
            return storedSnapshot
        }

        guard let builtSnapshot = try? await snapshotBuilder.buildSnapshot(forTrackId: trackID) else {
            return nil
        }

        await runtimeStore.storeSnapshot(builtSnapshot)
        return builtSnapshot
    }
}

/// Ограничитель параллельных async-операций.
private actor BatchTagMetadataAsyncLimiter {
    /// Максимальное количество одновременных операций.
    private let limit: Int
    /// Текущее количество активных операций.
    private var running = 0

    init(limit: Int) {
        self.limit = limit
    }

    /// Ожидает свободный слот.
    func acquire() async {
        while running >= limit {
            await Task.yield()
        }
        running += 1
    }

    /// Освобождает слот.
    func release() {
        running = max(0, running - 1)
    }
}
