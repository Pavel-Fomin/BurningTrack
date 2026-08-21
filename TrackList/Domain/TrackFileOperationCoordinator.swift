//
//  TrackFileOperationCoordinator.swift
//  TrackList
//
//  Последовательное владение конфликтующими файловыми операциями трека.
//
//  Created by Pavel Fomin on 21.08.2026.
//

import Foundation

/// Последовательно выполняет конфликтующие файловые операции одного трека.
///
/// Координатор не знает о файлах, bookmark-ах или UI. Он удерживает ownership
/// всего переданного domain-сценария, поэтому следующая команда того же трека
/// не может прочитать промежуточное состояние между физической мутацией и post-update.
actor TrackFileOperationCoordinator {

    /// Состояние очереди одного физического трека.
    private struct TrackState {
        /// Операция, которая уже владеет треком и может выполнять свой сценарий.
        let activeOperationID: UUID
        /// Явная FIFO-очередь ожидающих операций этого же трека.
        var waiters: [Waiter]
    }

    /// Ожидающая операция с собственной continuation для ровно одного resume.
    private struct Waiter {
        let operationID: UUID
        let continuation: CheckedContinuation<Void, Error>
    }

    /// Независимые очереди позволяют операциям разных треков идти параллельно.
    private var stateByTrackId: [UUID: TrackState] = [:]

    /// Выполняет один логический файловый сценарий с ownership конкретного трека.
    func run<Result>(
        trackId: UUID,
        operation: @Sendable () async throws -> Result
    ) async throws -> Result {
        let operationID = UUID()
        try Task.checkCancellation()
        try await acquire(trackId: trackId, operationID: operationID)

        do {
            // Отменённая в очереди задача не может перейти к выполнению её body.
            try Task.checkCancellation()
            let result = try await operation()
            release(trackId: trackId, operationID: operationID)
            return result
        } catch {
            // Ошибка и отмена освобождают ownership только после фактического выхода body.
            release(trackId: trackId, operationID: operationID)
            throw error
        }
    }

    /// Выполняет один batch-сценарий, удерживая ownership его треков до общего post-update.
    ///
    /// Стабильный порядок получения ownership исключает взаимное ожидание двух batch-операций.
    func run<Result>(
        trackIds: [UUID],
        operation: @Sendable () async throws -> Result
    ) async throws -> Result {
        let orderedTrackIds = Array(Set(trackIds)).sorted {
            $0.uuidString < $1.uuidString
        }
        var acquiredOperations: [(trackId: UUID, operationID: UUID)] = []

        do {
            for trackId in orderedTrackIds {
                let operationID = UUID()
                try Task.checkCancellation()
                try await acquire(trackId: trackId, operationID: operationID)
                acquiredOperations.append((trackId, operationID))
                // Отмена во время ожидания не запускает batch body после получения ownership.
                try Task.checkCancellation()
            }

            let result = try await operation()
            release(acquiredOperations)
            return result
        } catch {
            // Уже полученные треки возвращаются очередям, если batch не смог стартовать или завершиться.
            release(acquiredOperations)
            throw error
        }
    }

    /// Получает ownership сразу либо добавляет operation в FIFO-очередь трека.
    private func acquire(
        trackId: UUID,
        operationID: UUID
    ) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard var state = stateByTrackId[trackId] else {
                    stateByTrackId[trackId] = TrackState(
                        activeOperationID: operationID,
                        waiters: []
                    )
                    continuation.resume()
                    return
                }

                state.waiters.append(
                    Waiter(
                        operationID: operationID,
                        continuation: continuation
                    )
                )
                stateByTrackId[trackId] = state
            }
        } onCancel: {
            // Cancellation handler синхронный, поэтому удаление waiter выполняется отдельным actor hop.
            Task {
                await self.cancelWaitingOperation(
                    trackId: trackId,
                    operationID: operationID
                )
            }
        }
    }

    /// Удаляет отменённую ожидающую operation, не нарушая порядок остальных waiter-ов.
    private func cancelWaitingOperation(
        trackId: UUID,
        operationID: UUID
    ) {
        guard var state = stateByTrackId[trackId],
              state.activeOperationID != operationID,
              let waiterIndex = state.waiters.firstIndex(
                where: { $0.operationID == operationID }
              ) else {
            return
        }

        let waiter = state.waiters.remove(at: waiterIndex)
        stateByTrackId[trackId] = state
        waiter.continuation.resume(throwing: CancellationError())
    }

    /// Передаёт ownership следующему waiter-у либо очищает состояние трека.
    private func release(
        trackId: UUID,
        operationID: UUID
    ) {
        guard var state = stateByTrackId[trackId],
              state.activeOperationID == operationID else {
            return
        }

        guard state.waiters.isEmpty == false else {
            // После последней операции не оставляем словарь всех когда-либо изменённых trackId.
            stateByTrackId.removeValue(forKey: trackId)
            return
        }

        let nextWaiter = state.waiters.removeFirst()
        stateByTrackId[trackId] = TrackState(
            activeOperationID: nextWaiter.operationID,
            waiters: state.waiters
        )
        nextWaiter.continuation.resume()
    }

    /// Освобождает batch ownership в обратном порядке после полного выхода batch body.
    private func release(
        _ acquiredOperations: [(trackId: UUID, operationID: UUID)]
    ) {
        for acquiredOperation in acquiredOperations.reversed() {
            release(
                trackId: acquiredOperation.trackId,
                operationID: acquiredOperation.operationID
            )
        }
    }
}
