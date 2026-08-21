//
//  AsyncConcurrencyLimiter.swift
//  TrackList
//
//  Ограничивает число одновременно выполняемых асинхронных операций.
//
//  Created by Pavel Fomin on 21.08.2026.
//

import Foundation

/// Отменяемо ограничивает число одновременно выполняемых асинхронных операций.
///
/// Инварианты:
/// - ожидающие задачи не занимают поток и хранятся в явной FIFO-очереди;
/// - отмена удаляет waiter до последующей передачи слота;
/// - выданный слот освобождается только `withSlot` и ровно один раз;
/// - lock защищает только состояние слотов и continuation, никогда не работу операции.
final class AsyncConcurrencyLimiter: @unchecked Sendable {
    /// Нулевой или отрицательный лимит нормализуется в один безопасный рабочий слот.
    private let limit: Int
    /// Синхронизирует число слотов, FIFO-очередь и разрешение waiter-ов.
    private let lock = NSLock()
    /// Количество уже выданных слотов.
    private var running = 0
    /// Явная очередь сохраняет справедливый порядок живых ожидающих задач.
    private var waiters: [AsyncConcurrencyLimiterWaiter] = []

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    /// Ожидает свободный слот и возвращает false, если отмена победила до его выдачи.
    func acquire() async -> Bool {
        guard !Task.isCancelled else { return false }

        let waiterID = UUID()
        let waiterState = AsyncConcurrencyLimiterWaiterState()

        return await withTaskCancellationHandler {
            let immediateResult = lock.withLock { () -> Bool? in
                guard !Task.isCancelled else {
                    return false
                }

                guard running < limit else {
                    return nil
                }

                guard waiterState.grant() else {
                    return false
                }

                running += 1
                return true
            }
            if let immediateResult {
                return immediateResult
            }

            return await withCheckedContinuation { continuation in
                let shouldCancelContinuation = lock.withLock {
                    guard !Task.isCancelled, waiterState.isWaiting else {
                        return true
                    }

                    waiters.append(
                        AsyncConcurrencyLimiterWaiter(
                            id: waiterID,
                            continuation: continuation,
                            state: waiterState
                        )
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

    /// Выполняет operation только при владении слотом и всегда возвращает его после завершения.
    func withSlot<T>(
        operation: @escaping @Sendable () async -> T?
    ) async -> T? {
        guard await acquire() else { return nil }

        defer {
            release()
        }

        return await operation()
    }

    /// Передаёт слот первому живому waiter-у либо уменьшает число активных операций.
    func release() {
        let resolvedWaiters = lock.withLock { () -> (
            cancelled: [CheckedContinuation<Bool, Never>],
            granted: CheckedContinuation<Bool, Never>?
        ) in
            var cancelledContinuations: [CheckedContinuation<Bool, Never>] = []

            while !waiters.isEmpty {
                let waiter = waiters.removeFirst()
                if waiter.state.grant() {
                    return (cancelledContinuations, waiter.continuation)
                }

                cancelledContinuations.append(waiter.continuation)
            }

            running = max(0, running - 1)
            return (cancelledContinuations, nil)
        }

        resolvedWaiters.cancelled.forEach { continuation in
            continuation.resume(returning: false)
        }
        resolvedWaiters.granted?.resume(returning: true)
    }

    /// Удаляет отменённый waiter из очереди и завершает его continuation ровно один раз.
    private func cancelWaiter(id: UUID) {
        let waiter = lock.withLock { () -> AsyncConcurrencyLimiterWaiter? in
            guard let index = waiters.firstIndex(where: { $0.id == id }) else {
                return nil
            }

            return waiters.remove(at: index)
        }

        waiter?.continuation.resume(returning: false)
    }

    /// Доступно через @testable для проверки удаления отменённых waiter-ов.
    var waiterCount: Int {
        lock.withLock { waiters.count }
    }
}

/// Хранит атомарный исход одного waiter-а для гонки cancellation и grant.
private final class AsyncConcurrencyLimiterWaiterState: @unchecked Sendable {
    private enum Resolution {
        case waiting
        case granted
        case cancelled
    }

    /// Разделённое состояние защищено отдельным lock, который не удерживается при работе операции.
    private let lock = NSLock()
    private var resolution: Resolution = .waiting

    var isWaiting: Bool {
        lock.withLock { resolution == .waiting }
    }

    /// Фиксирует отмену, если слот ещё не был выдан задаче.
    func cancel() {
        lock.withLock {
            guard resolution == .waiting else { return }
            resolution = .cancelled
        }
    }

    /// Атомарно выдаёт слот только живому waiter-у.
    func grant() -> Bool {
        lock.withLock {
            guard resolution == .waiting else { return false }
            resolution = .granted
            return true
        }
    }

}

/// Объединяет continuation с его идентичностью и атомарным состоянием ожидания.
private struct AsyncConcurrencyLimiterWaiter {
    let id: UUID
    let continuation: CheckedContinuation<Bool, Never>
    let state: AsyncConcurrencyLimiterWaiterState
}
