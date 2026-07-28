//
//  WaveformCachedGenerator.swift
//  TrackList
//
//  Совместное использование генератора waveform и файлового кэша.
//
//  Created by Pavel Fomin on 28.07.2026.
//

import Foundation

/// Возвращает waveform из файлового кэша либо генерирует и сохраняет новый производный результат.
actor WaveformCachedGenerator: WaveformGenerating {

    /// Генератор отвечает только за декодирование аудиофайла.
    private let generator: any WaveformGenerating
    /// Кэш отвечает только за хранение производных данных вне SQLite.
    private let cache: any WaveformCaching

    /// Принимает зависимости явно, чтобы генератор и кэш проверялись и заменялись независимо.
    init(
        generator: any WaveformGenerating,
        cache: any WaveformCaching
    ) {
        self.generator = generator
        self.cache = cache
    }

    /// Сначала ищет соответствующую текущему файлу запись, затем генерирует waveform при промахе кэша.
    func generateSamples(
        from fileURL: URL,
        sampleCount: Int
    ) async throws -> [Double] {
        try await generateSamples(
            from: fileURL,
            cacheKey: fileURL.standardizedFileURL.path,
            sampleCount: sampleCount
        )
    }

    /// Использует ключ текущего трека вместе с fingerprint файла, чтобы ViewModel не проверяла актуальность кэша сама.
    func generateSamples(
        from fileURL: URL,
        cacheKey: String,
        sampleCount: Int
    ) async throws -> [Double] {
        if let cachedSamples = try? await cache.samples(
            for: fileURL,
            cacheKey: cacheKey,
            sampleCount: sampleCount
        ) {
            return cachedSamples
        }

        let generatedSamples = try await generator.generateSamples(
            from: fileURL,
            cacheKey: cacheKey,
            sampleCount: sampleCount
        )
        try Task.checkCancellation()

        // Ошибка кэша не отменяет уже готовый производный результат из аудиофайла.
        try? await cache.store(
            generatedSamples,
            for: fileURL,
            cacheKey: cacheKey,
            sampleCount: sampleCount
        )

        return generatedSamples
    }
}
