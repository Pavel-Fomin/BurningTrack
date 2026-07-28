//
//  WaveformFileCacheTests.swift
//  TrackList
//
//  Проверка файлового кэша waveform без мини-плеера и аудиодекодирования.
//
//  Created by Pavel Fomin on 28.07.2026.
//

import Foundation
import XCTest
@testable import TrackList

final class WaveformFileCacheTests: XCTestCase {

    /// Тестовый каталог изолирует JSON-кэш и его источник от файлов приложения.
    private var directoryURL: URL!

    override func setUpWithError() throws {
        directoryURL = try WaveformTestFileFactory.makeDirectory(
            named: "WaveformFileCacheTests"
        )
    }

    override func tearDownWithError() throws {
        if let directoryURL {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        directoryURL = nil
    }

    /// Кэш возвращает записанный нормализованный набор для неизменённого локального файла.
    func testStoreThenLoadSamplesForCurrentFile() async throws {
        let sourceURL = try WaveformTestFileFactory.makeRegularFile(
            in: directoryURL,
            named: "track.wav",
            contents: Data([0x01, 0x02, 0x03])
        )
        let cache = WaveformFileCache(
            directoryURL: directoryURL.appendingPathComponent("Cache", isDirectory: true)
        )
        let expectedSamples = [0.1, 0.4, 0.8, 1.0]

        try await cache.store(
            expectedSamples,
            for: sourceURL,
            sampleCount: expectedSamples.count
        )
        let loadedSamples = try await cache.samples(
            for: sourceURL,
            sampleCount: expectedSamples.count
        )

        XCTAssertEqual(loadedSamples, expectedSamples)
    }

    /// Запись с текущим единым размером мини-плеера принимается без повторной генерации.
    func testStoreThenLoadMiniPlayerSampleCount() async throws {
        let sourceURL = try WaveformTestFileFactory.makeRegularFile(
            in: directoryURL,
            named: "mini-player-track.wav",
            contents: Data([0x01, 0x02, 0x03])
        )
        let cache = WaveformFileCache(
            directoryURL: directoryURL.appendingPathComponent("Cache", isDirectory: true)
        )
        let expectedSamples = Array(
            repeating: 0.5,
            count: PlayerWaveformConfiguration.miniPlayerSampleCount
        )

        try await cache.store(
            expectedSamples,
            for: sourceURL,
            sampleCount: PlayerWaveformConfiguration.miniPlayerSampleCount
        )
        let loadedSamples = try await cache.samples(
            for: sourceURL,
            sampleCount: PlayerWaveformConfiguration.miniPlayerSampleCount
        )

        XCTAssertEqual(loadedSamples, expectedSamples)
    }

    /// Изменение размера исходного файла формирует другой ключ и не возвращает устаревший waveform.
    func testChangedSourceFileDoesNotReturnStaleSamples() async throws {
        let sourceURL = try WaveformTestFileFactory.makeRegularFile(
            in: directoryURL,
            named: "track.wav",
            contents: Data([0x01, 0x02, 0x03])
        )
        let cache = WaveformFileCache(
            directoryURL: directoryURL.appendingPathComponent("Cache", isDirectory: true)
        )

        try await cache.store(
            [0.2, 0.7],
            for: sourceURL,
            sampleCount: 2
        )
        try Data([0x01, 0x02, 0x03, 0x04]).write(
            to: sourceURL,
            options: .atomic
        )

        let loadedSamples = try await cache.samples(
            for: sourceURL,
            sampleCount: 2
        )

        XCTAssertNil(loadedSamples)
    }

    /// Размер waveform входит в ключ кэша и не допускает возврат набора другой длины.
    func testDifferentSampleCountDoesNotReuseCachedSamples() async throws {
        let sourceURL = try WaveformTestFileFactory.makeRegularFile(
            in: directoryURL,
            named: "track.wav",
            contents: Data([0x01, 0x02, 0x03])
        )
        let cache = WaveformFileCache(
            directoryURL: directoryURL.appendingPathComponent("Cache", isDirectory: true)
        )

        try await cache.store(
            [0.2, 0.7],
            for: sourceURL,
            sampleCount: 2
        )
        let loadedSamples = try await cache.samples(
            for: sourceURL,
            sampleCount: 4
        )

        XCTAssertNil(loadedSamples)
    }

    /// Старый формат из 64 значений не может выдаваться как готовая waveform из 128 значений.
    func testLegacy64SampleCacheIsNotAcceptedForMiniPlayer() async throws {
        let sourceURL = try WaveformTestFileFactory.makeRegularFile(
            in: directoryURL,
            named: "legacy-track.wav",
            contents: Data([0x01, 0x02, 0x03])
        )
        let cache = WaveformFileCache(
            directoryURL: directoryURL.appendingPathComponent("Cache", isDirectory: true)
        )
        let legacySamples = Array(repeating: 0.5, count: 64)

        try await cache.store(
            legacySamples,
            for: sourceURL,
            sampleCount: legacySamples.count
        )
        let loadedSamples = try await cache.samples(
            for: sourceURL,
            sampleCount: PlayerWaveformConfiguration.miniPlayerSampleCount
        )

        XCTAssertNil(loadedSamples)
    }
}
