//
//  WaveformGeneratorTests.swift
//  TrackList
//
//  Проверка генерации waveform из реального локального WAV-файла.
//
//  Created by Pavel Fomin on 28.07.2026.
//

import Foundation
import XCTest
@testable import TrackList

final class WaveformGeneratorTests: XCTestCase {

    /// Отдельный каталог исключает влияние файлов других тестов на локальный аудиоисточник.
    private var directoryURL: URL!

    override func setUpWithError() throws {
        directoryURL = try WaveformTestFileFactory.makeDirectory(
            named: "WaveformGeneratorTests"
        )
    }

    override func tearDownWithError() throws {
        if let directoryURL {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        directoryURL = nil
    }

    /// Генератор возвращает нормализованный набор ожидаемой длины из фактического локального WAV-файла.
    func testGenerateSamplesFromLocalWaveFile() async throws {
        let fileURL = try WaveformTestFileFactory.makeWaveFile(
            in: directoryURL,
            named: "levels.wav",
            segmentAmplitudes: [1_000, 5_000, 15_000, 30_000],
            framesPerSegment: 800
        )
        let generator = WaveformGenerator()

        let samples = try await generator.generateSamples(
            from: fileURL,
            sampleCount: 4
        )

        XCTAssertEqual(samples.count, 4)
        XCTAssertTrue(samples.allSatisfy { sample in
            sample.isFinite && (0...1).contains(sample)
        })
        XCTAssertEqual(samples[3], 1, accuracy: 0.01)
        XCTAssertLessThan(samples[0], samples[1])
        XCTAssertLessThan(samples[1], samples[2])
        XCTAssertLessThan(samples[2], samples[3])
    }

    /// Выборочный анализ сохраняет фиксированный контракт мини-плеера для тихих и громких участков файла.
    func testGenerateMiniPlayerSamplesFromQuietAndLoudSegments() async throws {
        let fileURL = try WaveformTestFileFactory.makeWaveFile(
            in: directoryURL,
            named: "mini-player-levels.wav",
            segmentAmplitudes: Array(repeating: 1_000, count: 32) +
                Array(repeating: 24_000, count: 32),
            framesPerSegment: 800
        )
        let generator = WaveformGenerator()

        let samples = try await generator.generateSamples(
            from: fileURL,
            sampleCount: PlayerWaveformConfiguration.miniPlayerSampleCount
        )

        XCTAssertEqual(PlayerWaveformConfiguration.miniPlayerSampleCount, 128)
        XCTAssertEqual(samples.count, PlayerWaveformConfiguration.miniPlayerSampleCount)
        XCTAssertTrue(samples.allSatisfy { sample in
            sample.isFinite && (0...1).contains(sample)
        })
        XCTAssertLessThan(samples[10], samples[50])
    }

    /// Повторный выбор тех же временных окон возвращает одинаковую форму без зависимости от случайных позиций.
    func testGenerateSamplesIsDeterministic() async throws {
        let fileURL = try WaveformTestFileFactory.makeWaveFile(
            in: directoryURL,
            named: "deterministic.wav",
            segmentAmplitudes: [2_000, 12_000, 6_000, 24_000],
            framesPerSegment: 1_600
        )
        let generator = WaveformGenerator()

        let firstSamples = try await generator.generateSamples(
            from: fileURL,
            sampleCount: 4
        )
        let secondSamples = try await generator.generateSamples(
            from: fileURL,
            sampleCount: 4
        )

        XCTAssertEqual(firstSamples, secondSamples)
    }

    /// Отмена до завершения не должна возвращать готовый waveform.
    func testCancelledGenerationDoesNotReturnSamples() async throws {
        let fileURL = try WaveformTestFileFactory.makeWaveFile(
            in: directoryURL,
            named: "cancellation.wav",
            segmentAmplitudes: Array(repeating: 16_000, count: 64),
            framesPerSegment: 20_000
        )
        let generator = WaveformGenerator()

        let task = Task {
            try await generator.generateSamples(
                from: fileURL,
                sampleCount: PlayerWaveformConfiguration.miniPlayerSampleCount
            )
        }
        await Task.yield()
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Отменённый генератор не должен возвращать waveform")
        } catch is CancellationError {
            // Ожидаемая отмена не является ошибкой генерации.
        } catch {
            XCTFail("Получена неверная ошибка: \(error)")
        }
    }

    /// Генератор отклоняет недопустимое количество ячеек до обращения к аудиофайлу.
    func testGenerateSamplesRejectsZeroSampleCount() async throws {
        let fileURL = try WaveformTestFileFactory.makeWaveFile(
            in: directoryURL,
            named: "silence.wav",
            segmentAmplitudes: [0],
            framesPerSegment: 800
        )
        let generator = WaveformGenerator()

        do {
            _ = try await generator.generateSamples(
                from: fileURL,
                sampleCount: 0
            )
            XCTFail("Генератор должен отклонять нулевое число ячеек")
        } catch let error as WaveformGenerationError {
            XCTAssertEqual(error, .invalidSampleCount)
        } catch {
            XCTFail("Получена неверная ошибка: \(error)")
        }
    }
}
