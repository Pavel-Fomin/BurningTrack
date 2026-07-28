//
//  WaveformCachedGeneratorTests.swift
//  TrackList
//
//  Проверка совместной работы генератора waveform и файлового кэша.
//
//  Created by Pavel Fomin on 28.07.2026.
//

import Foundation
import XCTest
@testable import TrackList

final class WaveformCachedGeneratorTests: XCTestCase {

    /// Тестовый каталог содержит и условный источник, и отдельную папку файлового кэша.
    private var directoryURL: URL!

    override func setUpWithError() throws {
        directoryURL = try WaveformTestFileFactory.makeDirectory(
            named: "WaveformCachedGeneratorTests"
        )
    }

    override func tearDownWithError() throws {
        if let directoryURL {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        directoryURL = nil
    }

    /// Повторный запрос того же файла получает первый результат из кэша без новой генерации.
    func testRepeatedRequestUsesFileCache() async throws {
        let sourceURL = try WaveformTestFileFactory.makeRegularFile(
            in: directoryURL,
            named: "track.wav",
            contents: Data([0x01, 0x02, 0x03])
        )
        let generatorSpy = WaveformGeneratorSpy(samples: [0.2, 0.7])
        let cache = WaveformFileCache(
            directoryURL: directoryURL.appendingPathComponent("Cache", isDirectory: true)
        )
        let generator = WaveformCachedGenerator(
            generator: generatorSpy,
            cache: cache
        )

        let firstResult = try await generator.generateSamples(
            from: sourceURL,
            sampleCount: 2
        )
        let secondResult = try await generator.generateSamples(
            from: sourceURL,
            sampleCount: 2
        )
        let callsCount = await generatorSpy.callsCount

        XCTAssertEqual(firstResult, [0.2, 0.7])
        XCTAssertEqual(secondResult, [0.2, 0.7])
        XCTAssertEqual(callsCount, 1)
    }

    /// Несовместимый 64-значный кэш пропускается, после чего сохраняется новый набор из 128 значений.
    func testLegacyMiniPlayerCacheTriggersNewGeneration() async throws {
        let sourceURL = try WaveformTestFileFactory.makeRegularFile(
            in: directoryURL,
            named: "legacy-track.wav",
            contents: Data([0x01, 0x02, 0x03])
        )
        let cache = WaveformFileCache(
            directoryURL: directoryURL.appendingPathComponent("Cache", isDirectory: true)
        )
        let legacySamples = Array(repeating: 0.2, count: 64)
        let refreshedSamples = Array(
            repeating: 0.7,
            count: PlayerWaveformConfiguration.miniPlayerSampleCount
        )
        let generatorSpy = WaveformGeneratorSpy(samples: refreshedSamples)
        let generator = WaveformCachedGenerator(generator: generatorSpy, cache: cache)

        try await cache.store(
            legacySamples,
            for: sourceURL,
            sampleCount: legacySamples.count
        )
        let generatedSamples = try await generator.generateSamples(
            from: sourceURL,
            sampleCount: PlayerWaveformConfiguration.miniPlayerSampleCount
        )
        let cachedSamples = try await cache.samples(
            for: sourceURL,
            sampleCount: PlayerWaveformConfiguration.miniPlayerSampleCount
        )
        let callsCount = await generatorSpy.callsCount

        XCTAssertEqual(generatedSamples, refreshedSamples)
        XCTAssertEqual(cachedSamples, refreshedSamples)
        XCTAssertEqual(callsCount, 1)
    }
}

/// Потокобезопасный генератор фиксирует обращения к реальному декодированию без зависимости от AVFoundation.
private actor WaveformGeneratorSpy: WaveformGenerating {

    /// Результат, который был бы получен после декодирования аудиофайла.
    private let samples: [Double]
    /// Счётчик показывает, что повторный запрос обслужил файловый кэш.
    private var calls = 0

    init(samples: [Double]) {
        self.samples = samples
    }

    /// Имитирует одну генерацию готовых нормализованных значений.
    func generateSamples(
        from fileURL: URL,
        sampleCount: Int
    ) async throws -> [Double] {
        calls += 1
        return samples
    }

    /// Возвращает число обращений к базовому генератору.
    var callsCount: Int {
        calls
    }
}
