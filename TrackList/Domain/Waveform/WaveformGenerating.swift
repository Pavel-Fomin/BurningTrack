//
//  WaveformGenerating.swift
//  TrackList
//
//  Контракт генерации производных амплитуд аудиофайла.
//
//  Created by Pavel Fomin on 28.07.2026.
//

import Foundation

/// Возвращает готовый небольшой набор нормализованных амплитуд для доступного локального аудиофайла.
protocol WaveformGenerating: Sendable {

    /// Создаёт значения waveform, распределённые по всей длительности аудиофайла.
    /// - Parameters:
    ///   - fileURL: URL доступного локального аудиофайла.
    ///   - sampleCount: Количество требуемых амплитуд.
    /// - Returns: Нормализованные значения от 0 до 1.
    func generateSamples(
        from fileURL: URL,
        sampleCount: Int
    ) async throws -> [Double]

    /// Создаёт waveform с устойчивым ключом runtime-трека для файлового кэша.
    func generateSamples(
        from fileURL: URL,
        cacheKey: String,
        sampleCount: Int
    ) async throws -> [Double]
}

extension WaveformGenerating {

    /// Сохраняет совместимость генераторов, которые декодируют файл и не управляют кэшем.
    func generateSamples(
        from fileURL: URL,
        cacheKey: String,
        sampleCount: Int
    ) async throws -> [Double] {
        try await generateSamples(
            from: fileURL,
            sampleCount: sampleCount
        )
    }
}

/// Причины, по которым нельзя получить waveform из локального источника.
enum WaveformGenerationError: Error, Equatable {
    /// Запрошено недопустимое количество амплитуд.
    case invalidSampleCount
    /// URL не указывает на доступный обычный файл.
    case localFileUnavailable
    /// Локальный файл недоступен для чтения.
    case localFileUnreadable
    /// В источнике не найдена аудиодорожка.
    case audioTrackUnavailable
    /// У аудио нет корректной положительной длительности.
    case invalidDuration
    /// AVFoundation не смог начать чтение аудиоданных.
    case readerStartFailed
    /// Запрошенный PCM-формат не был получен из AVAssetReader.
    case unsupportedPCMFormat
    /// В файле не оказалось доступных PCM-кадров.
    case audioSamplesUnavailable
    /// AVFoundation завершил чтение с ошибкой.
    case readerFailed
}
