//
//  AsyncConcurrencyLimiterTests.swift
//  TrackList
//
//  Проверяет инварианты общего ограничителя параллельных асинхронных операций.
//
//  Created by Pavel Fomin on 21.08.2026.
//

import XCTest
@testable import TrackList

@MainActor
final class AsyncConcurrencyLimiterTests: XCTestCase {

    func testMaximumConcurrencyNeverExceedsConfiguredLimit() async {
        let limiter = AsyncConcurrencyLimiter(limit: 3)
        let gate = ControlledLimiterOperationGate()
        let tasks = (0..<10).map { identifier in
            Task {
                await limiter.withSlot {
                    await gate.run(identifier: identifier)
                    return identifier
                }
            }
        }

        await gate.waitForStartedCount(3)
        await gate.waitForHeldCount(3)
        let maximumRunning = await gate.maximumRunning

        XCTAssertEqual(maximumRunning, 3)

        await gate.openAndResumeAll()
        for task in tasks {
            _ = await task.value
        }

        let finalMaximumRunning = await gate.maximumRunning
        XCTAssertEqual(finalMaximumRunning, 3)
    }

    /// Проверяет границу production limiter-а для типичных размеров массовой операции без device-dependent тайминга.
    func testBatchSizesKeepMaximumConcurrencyWithinConfiguredLimit() async {
        let limit = 6

        for count in [1, 10, 100, 300, 500] {
            let limiter = AsyncConcurrencyLimiter(limit: limit)
            let gate = ControlledLimiterOperationGate()
            let tasks = (0..<count).map { identifier in
                Task {
                    await limiter.withSlot {
                        await gate.run(identifier: identifier)
                        return identifier
                    }
                }
            }

            let expectedConcurrency = min(count, limit)
            await gate.waitForStartedCount(expectedConcurrency)
            await gate.waitForHeldCount(expectedConcurrency)
            let maximumRunning = await gate.maximumRunning

            XCTAssertEqual(maximumRunning, expectedConcurrency, "count=\(count)")

            await gate.openAndResumeAll()
            var completedResultCount = 0
            for task in tasks {
                if await task.value != nil {
                    completedResultCount += 1
                }
            }
            XCTAssertEqual(completedResultCount, count, "count=\(count)")
        }
    }

    func testWaitingOperationDoesNotStartBeforeOwnerReleasesSlot() async {
        let limiter = AsyncConcurrencyLimiter(limit: 1)
        let gate = ControlledLimiterOperationGate()

        let first = Task {
            await limiter.withSlot {
                await gate.run(identifier: 1)
                return 1
            }
        }
        await gate.waitForStartedCount(1)
        await gate.waitForHeldCount(1)

        let second = Task {
            await limiter.withSlot {
                await gate.run(identifier: 2)
                return 2
            }
        }
        await waitForWaiterCount(1, in: limiter)

        let startedBeforeRelease = await gate.startedIdentifiers
        XCTAssertEqual(startedBeforeRelease, [1])

        let resumedFirst = await gate.resumeNext()
        XCTAssertTrue(resumedFirst)
        await gate.waitForStartedCount(2)
        await gate.waitForHeldCount(1)

        let resumedSecond = await gate.resumeNext()
        XCTAssertTrue(resumedSecond)
        let firstResult = await first.value
        let secondResult = await second.value
        XCTAssertEqual(firstResult, 1)
        XCTAssertEqual(secondResult, 2)
    }

    func testCancelledQueuedOperationDoesNotConsumeSlotAndNextWaiterStarts() async {
        let limiter = AsyncConcurrencyLimiter(limit: 1)
        let gate = ControlledLimiterOperationGate()

        let first = Task {
            await limiter.withSlot {
                await gate.run(identifier: 1)
                return 1
            }
        }
        await gate.waitForStartedCount(1)
        await gate.waitForHeldCount(1)

        let cancelled = Task {
            await limiter.withSlot {
                await gate.run(identifier: 2)
                return 2
            }
        }
        let next = Task {
            await limiter.withSlot {
                await gate.run(identifier: 3)
                return 3
            }
        }
        await waitForWaiterCount(2, in: limiter)

        cancelled.cancel()
        let cancelledResult = await cancelled.value
        XCTAssertNil(cancelledResult)

        let resumedFirst = await gate.resumeNext()
        XCTAssertTrue(resumedFirst)
        await gate.waitForStartedCount(2)
        await gate.waitForHeldCount(1)

        let startedIdentifiers = await gate.startedIdentifiers
        XCTAssertEqual(startedIdentifiers, [1, 3])

        let resumedNext = await gate.resumeNext()
        XCTAssertTrue(resumedNext)
        let firstResult = await first.value
        let nextResult = await next.value
        XCTAssertEqual(firstResult, 1)
        XCTAssertEqual(nextResult, 3)
    }

    func testCancelledBeforeAcquireDoesNotRunOperationOrConsumeCapacity() async {
        let limiter = AsyncConcurrencyLimiter(limit: 1)
        let recorder = LimiterOperationRecorder()

        let cancelledTask = Task {
            await limiter.withSlot {
                await recorder.record(identifier: 1)
                return 1
            }
        }
        cancelledTask.cancel()

        let cancelledResult = await cancelledTask.value
        let startedIdentifiers = await recorder.startedIdentifiers

        XCTAssertNil(cancelledResult)
        XCTAssertTrue(startedIdentifiers.isEmpty)

        let replacementResult = await limiter.withSlot {
            await recorder.record(identifier: 2)
            return 2
        }
        XCTAssertEqual(replacementResult, 2)
    }

    func testSlotIsReleasedAfterNormalAndCancelledOwnerCompletion() async {
        let limiter = AsyncConcurrencyLimiter(limit: 1)
        let gate = ControlledLimiterOperationGate()

        let normalResult = await limiter.withSlot {
            return 1
        }
        XCTAssertEqual(normalResult, 1)

        let cancelledOwner = Task {
            await limiter.withSlot {
                await gate.run(identifier: 2)
                return 2
            }
        }
        await gate.waitForStartedCount(1)
        await gate.waitForHeldCount(1)
        cancelledOwner.cancel()

        let resumedOwner = await gate.resumeNext()
        XCTAssertTrue(resumedOwner)
        _ = await cancelledOwner.value

        let replacementResult = await limiter.withSlot {
            return 3
        }
        XCTAssertEqual(replacementResult, 3)
    }

    func testLivingWaitersReceiveSlotsInFIFOOrderAfterCancelledWaiterIsRemoved() async {
        let limiter = AsyncConcurrencyLimiter(limit: 1)
        let gate = ControlledLimiterOperationGate()

        let first = Task {
            await limiter.withSlot {
                await gate.run(identifier: 1)
                return 1
            }
        }
        await gate.waitForStartedCount(1)
        await gate.waitForHeldCount(1)

        let second = Task {
            await limiter.withSlot {
                await gate.run(identifier: 2)
                return 2
            }
        }
        let cancelledThird = Task {
            await limiter.withSlot {
                await gate.run(identifier: 3)
                return 3
            }
        }
        let fourth = Task {
            await limiter.withSlot {
                await gate.run(identifier: 4)
                return 4
            }
        }
        await waitForWaiterCount(3, in: limiter)

        cancelledThird.cancel()
        let cancelledThirdResult = await cancelledThird.value
        XCTAssertNil(cancelledThirdResult)

        let resumedFirst = await gate.resumeNext()
        XCTAssertTrue(resumedFirst)
        await gate.waitForStartedCount(2)
        await gate.waitForHeldCount(1)

        let resumedSecond = await gate.resumeNext()
        XCTAssertTrue(resumedSecond)
        await gate.waitForStartedCount(3)
        await gate.waitForHeldCount(1)

        let startedIdentifiers = await gate.startedIdentifiers
        XCTAssertEqual(startedIdentifiers, [1, 2, 4])

        let resumedFourth = await gate.resumeNext()
        XCTAssertTrue(resumedFourth)
        _ = await first.value
        _ = await second.value
        _ = await fourth.value
    }

    /// Ожидает постановку continuation в production-очередь без ожиданий по времени.
    private func waitForWaiterCount(
        _ expectedCount: Int,
        in limiter: AsyncConcurrencyLimiter
    ) async {
        for _ in 0..<128 {
            if limiter.waiterCount >= expectedCount {
                return
            }
            await Task.yield()
        }

        XCTFail("Ожидающий limiter waiter не попал в очередь")
    }
}

/// Управляемо удерживает operation после её старта, не используя файловую систему и ожидания по времени.
private actor ControlledLimiterOperationGate {
    private var started: [Int] = []
    private var running = 0
    private var maximum = 0
    private var isOpen = false
    private var heldContinuations: [CheckedContinuation<Void, Never>] = []
    private var startWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var heldWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    var startedIdentifiers: [Int] {
        started
    }

    var maximumRunning: Int {
        maximum
    }

    func run(identifier: Int) async {
        started.append(identifier)
        running += 1
        maximum = max(maximum, running)
        resumeStartWaitersIfNeeded()

        if !isOpen {
            await withCheckedContinuation { continuation in
                heldContinuations.append(continuation)
                resumeHeldWaitersIfNeeded()
            }
        }

        running -= 1
    }

    func waitForStartedCount(_ count: Int) async {
        guard started.count < count else { return }

        await withCheckedContinuation { continuation in
            startWaiters.append((count, continuation))
        }
    }

    func waitForHeldCount(_ count: Int) async {
        guard heldContinuations.count < count else { return }

        await withCheckedContinuation { continuation in
            heldWaiters.append((count, continuation))
        }
    }

    func resumeNext() -> Bool {
        guard !heldContinuations.isEmpty else { return false }

        heldContinuations.removeFirst().resume()
        return true
    }

    func openAndResumeAll() {
        isOpen = true
        let continuations = heldContinuations
        heldContinuations.removeAll()
        for continuation in continuations {
            continuation.resume()
        }
    }

    private func resumeStartWaitersIfNeeded() {
        var remaining: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

        for waiter in startWaiters {
            if started.count >= waiter.count {
                waiter.continuation.resume()
            } else {
                remaining.append(waiter)
            }
        }

        startWaiters = remaining
    }

    private func resumeHeldWaitersIfNeeded() {
        var remaining: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

        for waiter in heldWaiters {
            if heldContinuations.count >= waiter.count {
                waiter.continuation.resume()
            } else {
                remaining.append(waiter)
            }
        }

        heldWaiters = remaining
    }
}

/// Фиксирует старт operation для проверки отмены до acquire.
private actor LimiterOperationRecorder {
    private(set) var startedIdentifiers: [Int] = []

    func record(identifier: Int) {
        startedIdentifiers.append(identifier)
    }
}
