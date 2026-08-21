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
    /// Ограничивает число параллельных загрузок снимков.
    private let limiter: AsyncConcurrencyLimiter
    /// Выполняет чтение одного снимка после получения limiter slot.
    private let snapshotLoadingOperation: @Sendable (UUID) async -> TrackRuntimeSnapshot?

    init(
        runtimeStore: TrackRuntimeStore,
        snapshotBuilder: TrackRuntimeSnapshotBuilder,
        concurrentLimit: Int = 6
    ) {
        self.limiter = AsyncConcurrencyLimiter(limit: concurrentLimit)
        self.snapshotLoadingOperation = { trackID in
            await Self.loadSnapshot(
                trackID: trackID,
                runtimeStore: runtimeStore,
                snapshotBuilder: snapshotBuilder
            )
        }
    }

    /// Позволяет тестировать TaskGroup и limiter с управляемым runtime pipeline без файловой системы.
    init(
        concurrentLimit: Int,
        snapshotLoadingOperation: @escaping @Sendable (UUID) async -> TrackRuntimeSnapshot?
    ) {
        self.limiter = AsyncConcurrencyLimiter(limit: concurrentLimit)
        self.snapshotLoadingOperation = snapshotLoadingOperation
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
        let limiter = limiter
        let snapshotLoadingOperation = snapshotLoadingOperation

        guard !Task.isCancelled else { return [] }

        return await withTaskGroup(of: TrackRuntimeSnapshot?.self) { group in
            for trackID in trackIDs {
                guard !Task.isCancelled else { break }

                group.addTask {
                    guard !Task.isCancelled else { return nil }

                    return await limiter.withSlot {
                        // Отмена после выдачи слота всё равно оставляет withSlot единственным owner-ом release.
                        guard !Task.isCancelled else { return nil }
                        return await snapshotLoadingOperation(trackID)
                    }
                }
            }

            var snapshots: [TrackRuntimeSnapshot] = []
            for await snapshot in group {
                guard !Task.isCancelled else {
                    group.cancelAll()
                    return []
                }

                if let snapshot {
                    snapshots.append(snapshot)
                }
            }
            return snapshots
        }
    }

    /// Загружает снимок одного трека.
    private static func loadSnapshot(
        trackID: UUID,
        runtimeStore: TrackRuntimeStore,
        snapshotBuilder: TrackRuntimeSnapshotBuilder
    ) async -> TrackRuntimeSnapshot? {
        guard !Task.isCancelled else { return nil }

        if let storedSnapshot = await runtimeStore.snapshot(forTrackId: trackID) {
            return storedSnapshot
        }

        guard !Task.isCancelled,
              let builtSnapshot = try? await snapshotBuilder.buildSnapshot(forTrackId: trackID),
              !Task.isCancelled else {
            return nil
        }

        await runtimeStore.storeSnapshot(builtSnapshot)
        return builtSnapshot
    }
}
