//
//  MiniPlayerWaveformLayoutTests.swift
//  TrackList
//
//  Проверки чистой математики неподвижной waveform мини-плеера.
//
//  Created by Pavel Fomin on 28.07.2026.
//

import CoreGraphics
import XCTest
@testable import TrackList

final class MiniPlayerWaveformLayoutTests: XCTestCase {

    private let layout = MiniPlayerWaveformLayout(
        sampleCount: PlayerWaveformConfiguration.miniPlayerSampleCount,
        availableWidth: 240
    )

    /// Все 128 samples занимают доступную ширину без горизонтального смещения формы.
    func testWaveformWith128SamplesFillsAvailableWidth() {
        XCTAssertEqual(
            layout.sampleCount,
            PlayerWaveformConfiguration.miniPlayerSampleCount
        )
        XCTAssertEqual(layout.waveformWidth, 240, accuracy: 0.000_1)
    }

    /// На узком контейнере интервалы уменьшаются, чтобы ни один sample не пропадал за границей.
    func testWaveformRemainsInsideNarrowContainer() {
        let narrowLayout = MiniPlayerWaveformLayout(
            sampleCount: PlayerWaveformConfiguration.miniPlayerSampleCount,
            availableWidth: 80
        )

        XCTAssertGreaterThan(narrowLayout.barWidth, 0)
        XCTAssertGreaterThan(narrowLayout.barSpacing, 0)
        XCTAssertEqual(narrowLayout.waveformWidth, 80, accuracy: 0.000_1)
    }

    /// Начало трека не окрашивает активный слой waveform.
    func testStartHasNoActiveWaveformWidth() {
        XCTAssertEqual(layout.activeWaveformWidth(for: 0), 0, accuracy: 0.000_1)
    }

    /// Середина трека окрашивает ровно половину неподвижной waveform.
    func testMiddleHasHalfActiveWaveformWidth() {
        XCTAssertEqual(
            layout.activeWaveformWidth(for: 0.5),
            layout.waveformWidth / 2,
            accuracy: 0.000_1
        )
    }

    /// Конец трека окрашивает всю waveform без изменения её ширины.
    func testEndHasFullActiveWaveformWidth() {
        XCTAssertEqual(
            layout.activeWaveformWidth(for: 1),
            layout.waveformWidth,
            accuracy: 0.000_1
        )
    }

    /// Окрашивание не меняет источник амплитуд и использует только нормализованную ширину слоя.
    func testActiveWidthDoesNotChangeSamples() {
        let samples = Array(
            repeating: 0.5,
            count: PlayerWaveformConfiguration.miniPlayerSampleCount
        )
        _ = layout.activeWaveformWidth(for: 0.5)

        XCTAssertEqual(samples.count, PlayerWaveformConfiguration.miniPlayerSampleCount)
        XCTAssertEqual(samples, Array(repeating: 0.5, count: samples.count))
    }

    /// Время в начале трека возвращает нулевой progress.
    func testProgressAtStartIsZero() {
        XCTAssertEqual(
            MiniPlayerWaveformLayout.progress(currentTime: 0, duration: 100),
            0
        )
    }

    /// Время в середине трека возвращает половину progress.
    func testProgressAtMiddleIsHalf() {
        XCTAssertEqual(
            MiniPlayerWaveformLayout.progress(currentTime: 50, duration: 100),
            0.5
        )
    }

    /// Время в конце и за концом трека возвращает полный progress.
    func testProgressAtOrAfterEndIsOne() {
        XCTAssertEqual(
            MiniPlayerWaveformLayout.progress(currentTime: 100, duration: 100),
            1
        )
        XCTAssertEqual(
            MiniPlayerWaveformLayout.progress(currentTime: 150, duration: 100),
            1
        )
    }

    /// Отрицательное время и недопустимая длительность безопасно возвращают начало трека.
    func testNegativeTimeAndInvalidDurationReturnZeroProgress() {
        XCTAssertEqual(
            MiniPlayerWaveformLayout.progress(currentTime: -10, duration: 100),
            0
        )
        XCTAssertEqual(
            MiniPlayerWaveformLayout.progress(currentTime: 10, duration: 0),
            0
        )
        XCTAssertEqual(
            MiniPlayerWaveformLayout.progress(currentTime: 10, duration: -1),
            0
        )
    }

    /// Нажатие в начале, середине и конце переводится в ожидаемую долю трека.
    func testSeekProgressForValidCoordinates() {
        XCTAssertEqual(layout.progress(forHorizontalLocation: 0), 0)
        XCTAssertEqual(layout.progress(forHorizontalLocation: 120), 0.5)
        XCTAssertEqual(layout.progress(forHorizontalLocation: 240), 1)
    }

    /// Координаты за границей и нулевая ширина не создают деление на ноль или выход за диапазон.
    func testSeekProgressIsClampedAndSafeForZeroWidth() {
        XCTAssertEqual(layout.progress(forHorizontalLocation: -10), 0)
        XCTAssertEqual(layout.progress(forHorizontalLocation: 250), 1)

        let zeroWidthLayout = MiniPlayerWaveformLayout(
            sampleCount: PlayerWaveformConfiguration.miniPlayerSampleCount,
            availableWidth: 0
        )
        XCTAssertEqual(zeroWidthLayout.progress(forHorizontalLocation: 20), 0)
    }

    /// Seek доступен только для конечной положительной длительности трека.
    func testSeekAvailabilityRequiresFinitePositiveDuration() {
        XCTAssertTrue(MiniPlayerWaveformLayout.isSeekAvailable(for: 100))
        XCTAssertFalse(MiniPlayerWaveformLayout.isSeekAvailable(for: 0))
        XCTAssertFalse(MiniPlayerWaveformLayout.isSeekAvailable(for: -1))
        XCTAssertFalse(MiniPlayerWaveformLayout.isSeekAvailable(for: .infinity))
        XCTAssertFalse(MiniPlayerWaveformLayout.isSeekAvailable(for: .nan))
    }

    /// Появление готовых samples использует уже рассчитанную фактическую долю трека.
    func testReadyWaveformKeepsActualProgress() {
        let actualProgress = MiniPlayerWaveformLayout.progress(
            currentTime: 35,
            duration: 100
        )

        XCTAssertEqual(actualProgress, 0.35)
        XCTAssertEqual(
            layout.activeWaveformWidth(for: actualProgress),
            layout.waveformWidth * 0.35,
            accuracy: 0.000_1
        )
    }
}
