//
//  BatchFilenameRenameMetadataLoader.swift
//  TrackList
//
//  Загружает metadata для feature массового переименования файлов.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Загружает runtime metadata для immutable route, не зная о ViewModel и SwiftUI.
struct BatchFilenameRenameMetadataLoader: Sendable {
    /// Общее хранилище уже подготовленных runtime snapshots.
    private let runtimeStore: TrackRuntimeStore
    /// Builder отсутствующего snapshot из существующего runtime pipeline.
    private let snapshotBuilder: TrackRuntimeSnapshotBuilder
    /// Ограничитель удерживает число одновременных чтений metadata в заданной границе.
    private let limiter: AsyncConcurrencyLimiter

    init(
        runtimeStore: TrackRuntimeStore,
        snapshotBuilder: TrackRuntimeSnapshotBuilder,
        concurrentLimit: Int = 6
    ) {
        self.runtimeStore = runtimeStore
        self.snapshotBuilder = snapshotBuilder
        limiter = AsyncConcurrencyLimiter(limit: concurrentLimit)
    }

    /// Загружает snapshots и объединяет их с fallback-данными immutable route.
    func loadTracks(
        from seeds: [BatchFilenameRenameTrackSeed],
        progress: @escaping @MainActor @Sendable (Int, Int) -> Void
    ) async -> [BatchFilenameRenameTrack] {
        guard !Task.isCancelled else { return [] }

        let snapshotsByTrackID = await loadSnapshots(
            trackIDs: seeds.map(\.trackId),
            progress: progress
        )
        guard !Task.isCancelled else { return [] }

        return seeds.map { seed in
            BatchFilenameRenameTrack(
                seed: seed,
                snapshot: snapshotsByTrackID[seed.trackId]
            )
        }
    }

    /// Загружает snapshots с progress по завершению каждого трека и с отменяемым ожиданием лимита.
    private func loadSnapshots(
        trackIDs: [UUID],
        progress: @escaping @MainActor @Sendable (Int, Int) -> Void
    ) async -> [UUID: TrackRuntimeSnapshot] {
        let runtimeStore = runtimeStore
        let snapshotBuilder = snapshotBuilder
        let limiter = limiter
        let totalCount = trackIDs.count

        return await withTaskGroup(of: (UUID, TrackRuntimeSnapshot?).self) { group in
            for trackID in trackIDs {
                group.addTask {
                    let snapshot = await limiter.withSlot {
                        await Self.loadSnapshot(
                            trackID: trackID,
                            runtimeStore: runtimeStore,
                            snapshotBuilder: snapshotBuilder
                        )
                    }
                    return (trackID, snapshot)
                }
            }

            var snapshotsByTrackID: [UUID: TrackRuntimeSnapshot] = [:]
            var completedCount = 0

            for await (trackID, snapshot) in group {
                guard !Task.isCancelled else {
                    group.cancelAll()
                    return [:]
                }

                completedCount += 1
                await progress(completedCount, totalCount)
                if let snapshot {
                    snapshotsByTrackID[trackID] = snapshot
                }
            }

            return snapshotsByTrackID
        }
    }

    /// Берёт snapshot из store либо строит и сохраняет его в общей runtime-подсистеме.
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
