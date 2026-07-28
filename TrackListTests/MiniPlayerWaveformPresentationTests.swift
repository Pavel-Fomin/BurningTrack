//
//  MiniPlayerWaveformPresentationTests.swift
//  TrackList
//
//  Проверки выбора индикатора waveform в мини-плеере.
//
//  Created by Pavel Fomin on 28.07.2026.
//

import XCTest
@testable import TrackList

final class MiniPlayerWaveformPresentationTests: XCTestCase {

    /// Загрузка использует нейтральный placeholder waveform до появления готового результата.
    func testLoadingUsesWaveformPlaceholder() {
        let presentation = MiniPlayerWaveformPresentation(waveformState: .loading)

        XCTAssertEqual(presentation, .placeholder)
    }

    /// Готовый набор амплитуд передаётся в неподвижную waveform без преобразования во View.
    func testReadyUsesWaveformSamples() {
        let samples = [0.1, 0.8]
        let presentation = MiniPlayerWaveformPresentation(
            waveformState: .ready(samples)
        )

        XCTAssertEqual(presentation, .waveform(samples))
    }

    /// Ошибка построения использует ту же общую заглушку, что и остальные отсутствующие состояния.
    func testFailedUsesPlaceholderPresentation() {
        let presentation = MiniPlayerWaveformPresentation(waveformState: .failed)

        XCTAssertEqual(presentation, .placeholder)
    }

    /// Недоступный локальный источник использует ту же общую заглушку, что и ошибка построения.
    func testUnavailableUsesPlaceholderPresentation() {
        let presentation = MiniPlayerWaveformPresentation(waveformState: .unavailable)

        XCTAssertEqual(presentation, .placeholder)
    }

    /// Пустой набор амплитуд не создаёт интерактивную waveform и использует общую заглушку.
    func testEmptyReadySamplesUsePlaceholderPresentation() {
        let presentation = MiniPlayerWaveformPresentation(waveformState: .ready([]))

        XCTAssertEqual(presentation, .placeholder)
    }
}
