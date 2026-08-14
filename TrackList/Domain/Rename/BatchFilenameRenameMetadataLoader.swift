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
struct BatchFilenameRenameMetadataLoader {
    /// Общее хранилище уже подготовленных runtime snapshots.
    private let runtimeStore: TrackRuntimeStore
    /// Builder отсутствующего snapshot из существующего runtime pipeline.
    private let snapshotBuilder: TrackRuntimeSnapshotBuilder
    /// Ограничитель удерживает число одновременных чтений metadata в заданной границе.
    private let limiter: BatchFilenameRenameAsyncLimiter

    init(
        runtimeStore: TrackRuntimeStore,
        snapshotBuilder: TrackRuntimeSnapshotBuilder,
        concurrentLimit: Int = 6
    ) {
        self.runtimeStore = runtimeStore
        self.snapshotBuilder = snapshotBuilder
        limiter = BatchFilenameRenameAsyncLimiter(limit: concurrentLimit)
    }

    /// Загружает snapshots и объединяет их с fallback-данными immutable route.
    func loadTracks(
        from seeds: [BatchFilenameRenameTrackSeed],
        progress: @escaping @MainActor (Int, Int) -> Void
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
        progress: @escaping @MainActor (Int, Int) -> Void
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

/// Отменяемый ограничитель параллельных загрузок без busy-wait и бесконечного Task.yield().
final class BatchFilenameRenameAsyncLimiter: @unchecked Sendable {
    /// Максимальное количество одновременно выполняемых чтений.
    private let limit: Int
    /// Синхронизирует выдачу слотов и очередь continuation без отложенных cleanup-задач.
    private let lock = NSLock()
    /// Количество уже выданных слотов.
    private var running = 0
    /// Continuation и атомарное состояние ожидающих задач по их идентичности отмены.
    private var waiters: [UUID: BatchFilenameRenameLimiterWaiter] = [:]

    init(limit: Int) {
        self.limit = limit
    }

    /// Ожидает свободный слот и однозначно сообщает, был ли он выдан задаче.
    func acquire() async -> Bool {
        let waiterID = UUID()
        let waiterState = BatchFilenameRenameLimiterWaiterState()

        return await withTaskCancellationHandler {
            let immediateResult = lock.withLock { () -> Bool? in
                if Task.isCancelled {
                    return false
                }

                if running < limit {
                    running += 1
                    _ = waiterState.grant()
                    return true
                }

                return nil
            }
            if let immediateResult {
                return immediateResult
            }

            return await withCheckedContinuation { continuation in
                let shouldCancelContinuation = lock.withLock {
                    if Task.isCancelled || !waiterState.isWaiting {
                        return true
                    }

                    waiters[waiterID] = BatchFilenameRenameLimiterWaiter(
                        continuation: continuation,
                        state: waiterState
                    )
                    return false
                }
                if shouldCancelContinuation {
                    continuation.resume(returning: false)
                }
            }
        } onCancel: {
            waiterState.cancel()
            self.cancelWaiter(id: waiterID)
        }
    }

    /// Удерживает слот на всё время операции и освобождает его ровно один раз.
    func withSlot(
        operation: @escaping @Sendable () async -> TrackRuntimeSnapshot?
    ) async -> TrackRuntimeSnapshot? {
        guard await acquire() else { return nil }
        defer {
            release()
        }

        return await operation()
    }

    /// Передаёт освобождённый слот следующей задаче либо уменьшает число активных загрузок.
    func release() {
        let continuations = lock.withLock {
            var cancelledContinuations: [CheckedContinuation<Bool, Never>] = []
            var grantedContinuation: CheckedContinuation<Bool, Never>?

            while let waiterID = waiters.keys.first,
                  let waiter = waiters.removeValue(forKey: waiterID) {
                if waiter.state.grant() {
                    grantedContinuation = waiter.continuation
                    break
                }

                cancelledContinuations.append(waiter.continuation)
            }

            if grantedContinuation == nil {
                running = max(0, running - 1)
            }

            return (cancelledContinuations, grantedContinuation)
        }

        continuations.0.forEach { continuation in
            continuation.resume(returning: false)
        }
        continuations.1?.resume(returning: true)
    }

    /// Удаляет отменённую задачу из очереди ожидания, чтобы она не заняла слот позднее.
    private func cancelWaiter(id: UUID) {
        let waiter = lock.withLock {
            waiters.removeValue(forKey: id)
        }

        waiter?.continuation.resume(returning: false)
    }

    /// Доступно test target через @testable для проверки удаления отменённых waiter-ов.
    var waiterCount: Int {
        lock.withLock { waiters.count }
    }
}

/// Хранит атомарный исход waiter-а, доступный cancellation handler без ожидания actor-а.
private final class BatchFilenameRenameLimiterWaiterState: @unchecked Sendable {
    /// Состояние меняется только из waiting в один конечный исход.
    private enum Resolution {
        case waiting
        case granted
        case cancelled
    }

    private let lock = NSLock()
    private var resolution: Resolution = .waiting

    /// Показывает, что continuation ещё можно добавить в очередь limiter-а.
    var isWaiting: Bool {
        lock.lock()
        defer { lock.unlock() }
        return resolution == .waiting
    }

    /// Фиксирует отмену до постановки continuation либо до передачи слота.
    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        guard resolution == .waiting else { return }
        resolution = .cancelled
    }

    /// Передаёт слот только waiter-у, который не был отменён раньше передачи.
    func grant() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard resolution == .waiting else { return false }
        resolution = .granted
        return true
    }
}

/// Объединяет continuation с его атомарным состоянием cancellation.
private struct BatchFilenameRenameLimiterWaiter {
    let continuation: CheckedContinuation<Bool, Never>
    let state: BatchFilenameRenameLimiterWaiterState
}
