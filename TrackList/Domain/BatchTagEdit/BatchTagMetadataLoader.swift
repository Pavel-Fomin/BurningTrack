//
//  BatchTagMetadataLoader.swift
//  TrackList
//
//  Загружает метаданные для массового редактирования тегов.
//
//  Created by Pavel Fomin on 27.05.2026.
//

import Foundation

/// Загружает метаданные для массового редактирования тегов.
///
/// Роль:
/// - получает runtime-снимки выбранных треков;
/// - сначала проверяет TrackRuntimeStore;
/// - если snapshot отсутствует, строит его через TrackRuntimeSnapshotBuilder;
/// - собирает BatchTagEditFlow через BatchTagEditFlowBuilder;
/// - не знает про UI, SheetManager и сохранение тегов.
struct BatchTagMetadataLoader {
    /// Хранилище runtime-снимков.
    private let runtimeStore: TrackRuntimeStore
    /// Builder runtime-снимка.
    private let snapshotBuilder: TrackRuntimeSnapshotBuilder
    /// Ограничивает число параллельных загрузок снимков.
    private let limiter: BatchTagMetadataAsyncLimiter

    init(
        runtimeStore: TrackRuntimeStore,
        snapshotBuilder: TrackRuntimeSnapshotBuilder,
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

    /// Загружает снимки для выбранных треков.
    private func loadSnapshots(trackIDs: [UUID]) async -> [TrackRuntimeSnapshot] {
        let runtimeStore = runtimeStore
        let snapshotBuilder = snapshotBuilder
        let limiter = limiter

        return await withTaskGroup(of: TrackRuntimeSnapshot?.self) { group in
            for trackID in trackIDs {
                group.addTask {
                    await limiter.acquire()
                    defer {
                        // `defer` не поддерживает `await`, поэтому освобождение слота передаётся actor после завершения чтения.
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

    /// Загружает снимок одного трека.
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

/// Ограничитель параллельных асинхронных операций.
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
