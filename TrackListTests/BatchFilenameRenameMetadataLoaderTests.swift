//
//  BatchFilenameRenameMetadataLoaderTests.swift
//  TrackList
//
//  Проверяет cancellation-инварианты внутреннего limiter массового переименования файлов.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import XCTest
@testable import TrackList

/// Проверяет production limiter через internal @testable границу без раскрытия public API.
@MainActor
final class BatchFilenameRenameMetadataLoaderTests: XCTestCase {
    func testCancelledWaitingTaskDoesNotConsumeReleasedSlot() async {
        let limiter = BatchFilenameRenameAsyncLimiter(limit: 6)
        await acquireAllSlots(of: limiter)

        let cancelledWaiter = Task {
            await limiter.acquire()
        }
        await waitForWaiterCount(1, in: limiter)

        cancelledWaiter.cancel()
        limiter.release()

        let cancelledWaiterAcquiredSlot = await cancelledWaiter.value
        XCTAssertFalse(cancelledWaiterAcquiredSlot)

        let replacementAcquiredSlot = await limiter.acquire()
        XCTAssertTrue(replacementAcquiredSlot)
        limiter.release()
        releaseRemainingSlots(of: limiter, count: 5)
    }

    func testMultipleCancelledWaitersRestoreEntireCapacity() async {
        let limiter = BatchFilenameRenameAsyncLimiter(limit: 6)
        await acquireAllSlots(of: limiter)

        let cancelledWaiters = (0..<4).map { _ in
            Task {
                await limiter.acquire()
            }
        }
        await waitForWaiterCount(4, in: limiter)

        cancelledWaiters.forEach { $0.cancel() }
        var cancelledWaiterResults: [Bool] = []
        for cancelledWaiter in cancelledWaiters {
            cancelledWaiterResults.append(await cancelledWaiter.value)
        }
        XCTAssertEqual(cancelledWaiterResults, Array(repeating: false, count: 4))
        XCTAssertEqual(limiter.waiterCount, 0)

        releaseRemainingSlots(of: limiter, count: 6)

        var replacementResults: [Bool] = []
        for _ in 0..<6 {
            replacementResults.append(await limiter.acquire())
        }
        XCTAssertEqual(replacementResults, Array(repeating: true, count: 6))
        releaseRemainingSlots(of: limiter, count: 6)
    }

    func testSequentialCancelledSessionsRestoreCapacityForNewLoads() async {
        let limiter = BatchFilenameRenameAsyncLimiter(limit: 6)

        for _ in 0..<3 {
            await acquireAllSlots(of: limiter)

            let cancelledWaiter = Task {
                await limiter.acquire()
            }
            await waitForWaiterCount(1, in: limiter)
            cancelledWaiter.cancel()
            limiter.release()

            let cancelledWaiterAcquiredSlot = await cancelledWaiter.value
            XCTAssertFalse(cancelledWaiterAcquiredSlot)

            let nextSessionAcquiredSlot = await limiter.acquire()
            XCTAssertTrue(nextSessionAcquiredSlot)
            limiter.release()
            releaseRemainingSlots(of: limiter, count: 5)
        }
    }

    /// Занимает весь production limit перед управляемой отменой waiter-а.
    private func acquireAllSlots(
        of limiter: BatchFilenameRenameAsyncLimiter
    ) async {
        for _ in 0..<6 {
            let acquiredSlot = await limiter.acquire()
            XCTAssertTrue(acquiredSlot)
        }
    }

    /// Освобождает известное число занятых слотов после каждого тестового сценария.
    private func releaseRemainingSlots(
        of limiter: BatchFilenameRenameAsyncLimiter,
        count: Int
    ) {
        for _ in 0..<count {
            limiter.release()
        }
    }

    /// Ожидает постановку continuation в очередь через счётчик production limiter-а без sleep.
    private func waitForWaiterCount(
        _ expectedCount: Int,
        in limiter: BatchFilenameRenameAsyncLimiter
    ) async {
        for _ in 0..<128 {
            if limiter.waiterCount >= expectedCount {
                return
            }
            await Task.yield()
        }

        XCTFail("Limiter waiter did not reach expected count")
    }
}
