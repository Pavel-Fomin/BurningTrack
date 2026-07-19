//
//  OperationTimeEstimatorTests.swift
//  TrackList
//
//  Проверки стабильной оценки времени универсальной операции.
//
//  Created by Pavel Fomin on 19.07.2026.
//

import Foundation
import XCTest
@testable import TrackList

/// Проверяет окно наблюдения, сглаживание и сброс оценщика времени.
final class OperationTimeEstimatorTests: XCTestCase {

    /// До минимальной длительности наблюдения оценка не показывается пользователю.
    func testEstimatorWaitsForMinimumObservationDuration() {
        var estimator = OperationTimeEstimator()
        let startDate = Date(timeIntervalSinceReferenceDate: 1_000)
        estimator.reset(startDate: startDate)

        XCTAssertNil(
            estimator.recordProgress(
                completedUnits: 1,
                totalUnits: 10,
                date: startDate.addingTimeInterval(1)
            )
        )
        XCTAssertNil(
            estimator.recordProgress(
                completedUnits: 2,
                totalUnits: 10,
                date: startDate.addingTimeInterval(2)
            )
        )
        XCTAssertNil(
            estimator.recordProgress(
                completedUnits: 3,
                totalUnits: 10,
                date: startDate.addingTimeInterval(3)
            )
        )
        XCTAssertNotNil(
            estimator.recordProgress(
                completedUnits: 4,
                totalUnits: 10,
                date: startDate.addingTimeInterval(4)
            )
        )
    }

    /// Повторный снимок без изменения прогресса не искажает скорость.
    func testEstimatorIgnoresUnchangedProgress() {
        var estimator = OperationTimeEstimator()
        let startDate = Date(timeIntervalSinceReferenceDate: 2_000)
        estimator.reset(startDate: startDate)

        let firstEstimate = estimator.recordProgress(
            completedUnits: 4,
            totalUnits: 10,
            date: startDate.addingTimeInterval(4)
        )
        XCTAssertNotNil(firstEstimate)

        XCTAssertNil(
            estimator.recordProgress(
                completedUnits: 4,
                totalUnits: 10,
                date: startDate.addingTimeInterval(100)
            )
        )

        let nextEstimate = estimator.recordProgress(
            completedUnits: 5,
            totalUnits: 10,
            date: startDate.addingTimeInterval(5)
        )
        XCTAssertNotNil(nextEstimate)
        XCTAssertEqual(
            nextEstimate!.timeIntervalSince(startDate),
            10,
            accuracy: 0.001
        )
    }

    /// Равномерный байтовый поток сохраняет одну и ту же дату завершения.
    func testEstimatorKeepsEndDateForStableByteRate() {
        var estimator = OperationTimeEstimator()
        let startDate = Date(timeIntervalSinceReferenceDate: 2_500)
        let totalBytes: Int64 = 1_000
        estimator.reset(startDate: startDate)

        for second in 1...3 {
            XCTAssertNil(
                estimator.recordProgress(
                    completedUnits: Int64(second * 100),
                    totalUnits: totalBytes,
                    date: startDate.addingTimeInterval(TimeInterval(second))
                )
            )
        }

        let firstEstimate = estimator.recordProgress(
            completedUnits: 400,
            totalUnits: totalBytes,
            date: startDate.addingTimeInterval(4)
        )
        let nextEstimate = estimator.recordProgress(
            completedUnits: 500,
            totalUnits: totalBytes,
            date: startDate.addingTimeInterval(5)
        )

        XCTAssertNotNil(firstEstimate)
        XCTAssertNotNil(nextEstimate)
        XCTAssertEqual(
            firstEstimate!.timeIntervalSince(startDate),
            10,
            accuracy: 0.001
        )
        XCTAssertEqual(
            nextEstimate!.timeIntervalSince(startDate),
            10,
            accuracy: 0.001
        )
    }

    /// Новая операция получает полностью чистую статистику оценщика.
    func testEstimatorResetClearsPreviousStatistics() {
        var estimator = OperationTimeEstimator()
        let firstStartDate = Date(timeIntervalSinceReferenceDate: 3_000)
        estimator.reset(startDate: firstStartDate)
        _ = estimator.recordProgress(
            completedUnits: 4,
            totalUnits: 10,
            date: firstStartDate.addingTimeInterval(4)
        )

        let secondStartDate = Date(timeIntervalSinceReferenceDate: 4_000)
        estimator.reset(startDate: secondStartDate)

        XCTAssertNil(
            estimator.recordProgress(
                completedUnits: 1,
                totalUnits: 10,
                date: secondStartDate.addingTimeInterval(1)
            )
        )
    }

    /// Прогресс на последней единице не создаёт отрицательный интервал времени.
    func testEstimatorClampsRemainingTimeToZero() {
        var estimator = OperationTimeEstimator()
        let startDate = Date(timeIntervalSinceReferenceDate: 5_000)
        estimator.reset(startDate: startDate)

        let estimate = estimator.recordProgress(
            completedUnits: 4,
            totalUnits: 4,
            date: startDate.addingTimeInterval(4)
        )

        XCTAssertNotNil(estimate)
        XCTAssertEqual(
            estimate!.timeIntervalSince(startDate),
            4,
            accuracy: 0.001
        )
    }
}
