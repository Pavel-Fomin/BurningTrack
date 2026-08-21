//
//  MiniPlayerWaveformPlaceholderViewTests.swift
//  TrackList
//
//  Проверки геометрии заглушки waveform мини-плеера.
//
//  Created by Pavel Fomin on 28.07.2026.
//

import CoreGraphics
import XCTest
@testable import TrackList

@MainActor
final class MiniPlayerWaveformPlaceholderViewTests: XCTestCase {

    /// Высота заглушки соответствует контейнеру готовой waveform и не меняет разметку мини-плеера.
    func testPlaceholderUsesWaveformContainerHeight() {
        XCTAssertEqual(MiniPlayerWaveformPlaceholderView.containerHeight, 20)
    }

    /// Точки пустой формы сохраняют заданные фиксированные размер и интервал.
    func testPlaceholderUsesFixedDotGeometry() {
        XCTAssertEqual(
            MiniPlayerWaveformPlaceholderView.dotWidth,
            2
        )
        XCTAssertEqual(
            MiniPlayerWaveformPlaceholderView.dotSpacing,
            2
        )
    }

    /// Количество точек сокращается на узкой ширине, не нарушая заданный размер или интервал.
    func testPlaceholderUsesMaximumDotCountThatFitsContainer() {
        XCTAssertEqual(
            MiniPlayerWaveformPlaceholderView.dotCount(for: 250),
            63
        )
        XCTAssertEqual(
            MiniPlayerWaveformPlaceholderView.lineWidth(for: 63),
            250
        )
        XCTAssertEqual(
            MiniPlayerWaveformPlaceholderView.dotCount(for: 1),
            0
        )
    }
}
