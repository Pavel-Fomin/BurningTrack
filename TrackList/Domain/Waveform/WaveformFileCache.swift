//
//  WaveformFileCache.swift
//  TrackList
//
//  Файловое хранение производных амплитуд аудиофайлов.
//
//  Created by Pavel Fomin on 28.07.2026.
//

import CryptoKit
import Foundation

/// Контракт файлового кэша waveform, допускающий отдельную проверку без генератора.
protocol WaveformCaching: Sendable {

    /// Возвращает кэшированные значения для текущей версии файла либо nil при отсутствии записи.
    func samples(
        for fileURL: URL,
        cacheKey: String,
        sampleCount: Int
    ) async throws -> [Double]?

    /// Сохраняет готовые нормализованные значения для текущей версии файла.
    func store(
        _ samples: [Double],
        for fileURL: URL,
        cacheKey: String,
        sampleCount: Int
    ) async throws
}

extension WaveformCaching {

    /// Сохраняет прежний вызов для изолированных проверок и использует путь файла как локальный ключ.
    func samples(
        for fileURL: URL,
        sampleCount: Int
    ) async throws -> [Double]? {
        try await samples(
            for: fileURL,
            cacheKey: fileURL.standardizedFileURL.path,
            sampleCount: sampleCount
        )
    }

    /// Сохраняет прежнюю запись кэша для существующих клиентов без явного ключа трека.
    func store(
        _ samples: [Double],
        for fileURL: URL,
        sampleCount: Int
    ) async throws {
        try await store(
            samples,
            for: fileURL,
            cacheKey: fileURL.standardizedFileURL.path,
            sampleCount: sampleCount
        )
    }
}

/// Ошибки валидации входных данных файлового кэша waveform.
enum WaveformFileCacheError: Error, Equatable {
    /// Запрошено недопустимое количество амплитуд.
    case invalidSampleCount
    /// Переданный файл недоступен для построения стабильного ключа.
    case sourceUnavailable
    /// Значения не соответствуют нормализованному контракту waveform.
    case invalidSamples
}

/// Хранит производные waveform отдельно от SQLite и основных данных приложения.
actor WaveformFileCache: WaveformCaching {

    /// Версия изолирует формат кэша от будущих изменений алгоритма нормализации.
    private static let cacheVersion = 1
    /// Каталог хранит только производные данные, которые система может очищать как обычный кэш.
    private let directoryURL: URL

    /// Создаёт кэш в системном Caches либо в переданном тестовом каталоге.
    init(directoryURL: URL? = nil) {
        self.directoryURL = directoryURL ?? Self.defaultDirectoryURL
    }

    /// Возвращает кэшированные значения, удаляя только повреждённый файл своей подсистемы.
    func samples(
        for fileURL: URL,
        cacheKey: String,
        sampleCount: Int
    ) throws -> [Double]? {
        let cacheFileURL = try cacheFileURL(
            for: fileURL,
            cacheKey: cacheKey,
            sampleCount: sampleCount
        )

        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: cacheFileURL)
            let record = try JSONDecoder().decode(CachedWaveform.self, from: data)

            // Несовпадение sampleCount, включая старые 64 значения после перехода на 128, требует безопасной перестройки производного waveform.
            guard record.version == Self.cacheVersion,
                  record.sampleCount == sampleCount,
                  isValid(samples: record.samples, expectedCount: sampleCount)
            else {
                try? FileManager.default.removeItem(at: cacheFileURL)
                return nil
            }

            return record.samples
        } catch {
            // Повреждённая производная запись не должна блокировать следующую генерацию waveform.
            try? FileManager.default.removeItem(at: cacheFileURL)
            return nil
        }
    }

    /// Атомарно сохраняет только полный и нормализованный результат генератора.
    func store(
        _ samples: [Double],
        for fileURL: URL,
        cacheKey: String,
        sampleCount: Int
    ) throws {
        guard isValid(samples: samples, expectedCount: sampleCount) else {
            throw WaveformFileCacheError.invalidSamples
        }

        let cacheFileURL = try cacheFileURL(
            for: fileURL,
            cacheKey: cacheKey,
            sampleCount: sampleCount
        )
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let record = CachedWaveform(
            version: Self.cacheVersion,
            sampleCount: sampleCount,
            samples: samples
        )
        let data = try JSONEncoder().encode(record)
        try data.write(to: cacheFileURL, options: .atomic)
    }

    // MARK: - Cache key

    /// Возвращает отдельный каталожный путь для производных данных приложения.
    private static var defaultDirectoryURL: URL {
        let cachesDirectory = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]
        return cachesDirectory.appendingPathComponent(
            "Waveforms",
            isDirectory: true
        )
    }

    /// Строит имя кэша по ключу трека и fingerprint текущей версии файла.
    private func cacheFileURL(
        for fileURL: URL,
        cacheKey: String,
        sampleCount: Int
    ) throws -> URL {
        guard sampleCount > 0 else {
            throw WaveformFileCacheError.invalidSampleCount
        }

        guard fileURL.isFileURL else {
            throw WaveformFileCacheError.sourceUnavailable
        }

        let resourceValues = try fileURL.resourceValues(
            forKeys: [
                .isRegularFileKey,
                .fileSizeKey,
                .contentModificationDateKey,
                .fileResourceIdentifierKey
            ]
        )
        guard resourceValues.isRegularFile == true else {
            throw WaveformFileCacheError.sourceUnavailable
        }

        let fingerprint = [
            "version=\(Self.cacheVersion)",
            "track=\(cacheKey)",
            "path=\(fileURL.standardizedFileURL.path)",
            "size=\(resourceValues.fileSize ?? -1)",
            "modified=\(resourceValues.contentModificationDate?.timeIntervalSinceReferenceDate ?? -1)",
            "identifier=\(String(describing: resourceValues.fileResourceIdentifier))",
            "samples=\(sampleCount)"
        ].joined(separator: "|")
        let digest = SHA256.hash(data: Data(fingerprint.utf8))
        let fileName = digest.map { String(format: "%02x", $0) }.joined() + ".json"

        return directoryURL.appendingPathComponent(fileName, isDirectory: false)
    }

    // MARK: - Validation

    /// Проверяет размер, конечность и диапазон значений перед выдачей либо записью в кэш.
    private func isValid(samples: [Double], expectedCount: Int) -> Bool {
        guard expectedCount > 0, samples.count == expectedCount else {
            return false
        }

        return samples.allSatisfy { sample in
            sample.isFinite && (0...1).contains(sample)
        }
    }
}

/// Кодируемая запись позволяет не считать JSON-кэш источником истины приложения.
private struct CachedWaveform: Codable {
    let version: Int
    let sampleCount: Int
    let samples: [Double]
}
