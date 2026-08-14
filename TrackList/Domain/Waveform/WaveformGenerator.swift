//
//  WaveformGenerator.swift
//  TrackList
//
//  Асинхронное построение нормализованных амплитуд локального аудиофайла.
//
//  Created by Pavel Fomin on 28.07.2026.
//

import AudioToolbox
import AVFoundation
import Foundation

/// Декодирует небольшие равномерно распределённые фрагменты локального аудиофайла вне UI.
actor WaveformGenerator: WaveformGenerating {

    /// Четверть секунды даёт устойчивую RMS-оценку, но не требует декодировать значительную часть длинного трека.
    private static let analysisWindowDuration: Double = 0.25
    /// Высокая временная точность сохраняет ненулевые окна даже для очень коротких файлов.
    private static let analysisTimeScale: CMTimeScale = 60_000

    /// Создаёт нормализованные RMS-амплитуды из коротких детерминированных окон по всей длительности файла.
    func generateSamples(
        from fileURL: URL,
        sampleCount: Int
    ) async throws -> [Double] {
        guard sampleCount > 0 else {
            throw WaveformGenerationError.invalidSampleCount
        }

        try validateReadableLocalFile(at: fileURL)
        try Task.checkCancellation()

        let asset = AVURLAsset(url: fileURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw WaveformGenerationError.invalidDuration
        }

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let audioTrack = audioTracks.first else {
            throw WaveformGenerationError.audioTrackUnavailable
        }

        do {
            return try generateSamplesUsingWindows(
                asset: asset,
                audioTrack: audioTrack,
                durationSeconds: durationSeconds,
                sampleCount: sampleCount
            )
        } catch let error as CancellationError {
            throw error
        } catch let error as WaveformGenerationError where
            error == .readerStartFailed ||
                error == .readerFailed ||
                error == .audioSamplesUnavailable {
            // Формат без надёжного выборочного чтения сохраняет общий последовательный путь вместо отказа waveform.
            try Task.checkCancellation()
            return try generateSamplesSequentially(
                asset: asset,
                audioTrack: audioTrack,
                durationSeconds: durationSeconds,
                sampleCount: sampleCount
            )
        }
    }

    // MARK: - Валидация входных данных

    /// Проверяет, что генератор получает доступный обычный файл, а не каталог или media-library URL.
    private func validateReadableLocalFile(at fileURL: URL) throws {
        guard fileURL.isFileURL,
              FileManager.default.fileExists(atPath: fileURL.path)
        else {
            throw WaveformGenerationError.localFileUnavailable
        }

        let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
        guard resourceValues.isRegularFile == true else {
            throw WaveformGenerationError.localFileUnavailable
        }

        guard FileManager.default.isReadableFile(atPath: fileURL.path) else {
            throw WaveformGenerationError.localFileUnreadable
        }
    }

    // MARK: - Выборочное чтение

    /// Выбирает центральное короткое окно каждого равного временного участка, чтобы форма была повторяемой.
    private func generateSamplesUsingWindows(
        asset: AVAsset,
        audioTrack: AVAssetTrack,
        durationSeconds: Double,
        sampleCount: Int
    ) throws -> [Double] {
        var rootMeanSquares: [Double] = []
        rootMeanSquares.reserveCapacity(sampleCount)
        var hasAudioFrames = false

        for sampleIndex in 0..<sampleCount {
            // Проверка до следующего окна прекращает ненужную работу сразу после смены трека.
            try Task.checkCancellation()

            let timeRange = analysisTimeRange(
                sampleIndex: sampleIndex,
                sampleCount: sampleCount,
                durationSeconds: durationSeconds
            )
            let contribution = try readWindow(
                in: timeRange,
                asset: asset,
                audioTrack: audioTrack
            )

            // Проверка после чтения не позволяет нормализовать результат уже отменённой задачи.
            try Task.checkCancellation()

            guard contribution.framesCount > 0 else {
                rootMeanSquares.append(0)
                continue
            }

            hasAudioFrames = true
            rootMeanSquares.append(
                sqrt(contribution.squaredAmplitudeSum / Double(contribution.framesCount))
            )
        }

        guard hasAudioFrames else {
            throw WaveformGenerationError.audioSamplesUnavailable
        }

        try Task.checkCancellation()
        return normalizedSamples(rootMeanSquares)
    }

    /// Строит временной диапазон, центрированный внутри своего сегмента и ограниченный длительностью самого сегмента.
    private func analysisTimeRange(
        sampleIndex: Int,
        sampleCount: Int,
        durationSeconds: Double
    ) -> CMTimeRange {
        let segmentStart = durationSeconds * Double(sampleIndex) / Double(sampleCount)
        let segmentEnd = durationSeconds * Double(sampleIndex + 1) / Double(sampleCount)
        let segmentDuration = segmentEnd - segmentStart
        let windowDuration = min(Self.analysisWindowDuration, segmentDuration)
        let windowStart = segmentStart + (segmentDuration - windowDuration) / 2

        return CMTimeRange(
            start: CMTime(
                seconds: windowStart,
                preferredTimescale: Self.analysisTimeScale
            ),
            duration: CMTime(
                seconds: windowDuration,
                preferredTimescale: Self.analysisTimeScale
            )
        )
    }

    /// Читает один небольшой диапазон без накопления PCM всего трека в памяти.
    private func readWindow(
        in timeRange: CMTimeRange,
        asset: AVAsset,
        audioTrack: AVAssetTrack
    ) throws -> PCMContribution {
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = timeRange
        let output = makePCMOutput(for: audioTrack)

        guard reader.canAdd(output) else {
            throw WaveformGenerationError.readerStartFailed
        }

        reader.add(output)

        guard reader.startReading() else {
            throw WaveformGenerationError.readerStartFailed
        }

        defer {
            reader.cancelReading()
        }

        var contribution = PCMContribution()

        while let sampleBuffer = output.copyNextSampleBuffer() {
            // Проверка сразу после декодирования буфера избегает расчёта отменённого окна.
            try Task.checkCancellation()

            guard let pcmBuffer = try decodedPCMBuffer(from: sampleBuffer) else {
                continue
            }

            for frameIndex in 0..<pcmBuffer.framesCount {
                contribution.add(
                    squaredAmplitude: squaredAmplitude(for: frameIndex, in: pcmBuffer)
                )
            }
        }

        try Task.checkCancellation()

        guard reader.status == .completed else {
            throw WaveformGenerationError.readerFailed
        }

        return contribution
    }

    // MARK: - Последовательный fallback

    /// Последовательный путь используется только если формат не позволяет запустить выборочное чтение.
    private func generateSamplesSequentially(
        asset: AVAsset,
        audioTrack: AVAssetTrack,
        durationSeconds: Double,
        sampleCount: Int
    ) throws -> [Double] {
        let reader = try AVAssetReader(asset: asset)
        let output = makePCMOutput(for: audioTrack)

        guard reader.canAdd(output) else {
            throw WaveformGenerationError.readerStartFailed
        }

        reader.add(output)

        guard reader.startReading() else {
            throw WaveformGenerationError.readerStartFailed
        }

        defer {
            reader.cancelReading()
        }

        var squaredAmplitudeSums = Array(repeating: 0.0, count: sampleCount)
        var frameCounts = Array(repeating: 0, count: sampleCount)
        var hasAudioFrames = false

        while let sampleBuffer = output.copyNextSampleBuffer() {
            try Task.checkCancellation()

            guard let pcmBuffer = try decodedPCMBuffer(from: sampleBuffer) else {
                continue
            }

            for frameIndex in 0..<pcmBuffer.framesCount {
                let seconds = max(
                    pcmBuffer.presentationTime + Double(frameIndex) / pcmBuffer.sampleRate,
                    0
                )
                let normalizedPosition = min(max(seconds / durationSeconds, 0), 1)
                let sampleIndex = min(
                    Int(normalizedPosition * Double(sampleCount)),
                    sampleCount - 1
                )

                squaredAmplitudeSums[sampleIndex] += squaredAmplitude(
                    for: frameIndex,
                    in: pcmBuffer
                )
                frameCounts[sampleIndex] += 1
                hasAudioFrames = true
            }
        }

        try Task.checkCancellation()

        guard reader.status == .completed else {
            throw WaveformGenerationError.readerFailed
        }

        guard hasAudioFrames else {
            throw WaveformGenerationError.audioSamplesUnavailable
        }

        return normalizedSamples(
            squaredAmplitudeSums: squaredAmplitudeSums,
            frameCounts: frameCounts
        )
    }

    // MARK: - Чтение PCM

    /// Запрашивает единый interleaved PCM-формат, чтобы одинаково вычислять амплитуды для поддерживаемых контейнеров.
    private func makePCMOutput(for audioTrack: AVAssetTrack) -> AVAssetReaderTrackOutput {
        let output = AVAssetReaderTrackOutput(
            track: audioTrack,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
        )
        output.alwaysCopiesSampleData = false
        return output
    }

    /// Извлекает из одного PCM-буфера только данные, необходимые для текущего окна или fallback-прохода.
    private func decodedPCMBuffer(
        from sampleBuffer: CMSampleBuffer
    ) throws -> DecodedPCMBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(
                formatDescription
              )?.pointee
        else {
            throw WaveformGenerationError.unsupportedPCMFormat
        }

        let channelsCount = Int(streamDescription.mChannelsPerFrame)
        let bytesPerFrame = Int(streamDescription.mBytesPerFrame)
        let sampleRate = streamDescription.mSampleRate

        guard streamDescription.mFormatID == kAudioFormatLinearPCM,
              streamDescription.mBitsPerChannel == 16,
              channelsCount > 0,
              bytesPerFrame >= channelsCount * MemoryLayout<Int16>.size,
              sampleRate.isFinite,
              sampleRate > 0
        else {
            throw WaveformGenerationError.unsupportedPCMFormat
        }

        let framesCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard framesCount > 0,
              let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer)
        else {
            return nil
        }

        let requiredByteCount = framesCount * bytesPerFrame
        guard CMBlockBufferGetDataLength(blockBuffer) >= requiredByteCount else {
            throw WaveformGenerationError.readerFailed
        }

        var pcmBytes = Array(repeating: UInt8.zero, count: requiredByteCount)
        let copyStatus = pcmBytes.withUnsafeMutableBytes { buffer in
            CMBlockBufferCopyDataBytes(
                blockBuffer,
                atOffset: 0,
                dataLength: requiredByteCount,
                destination: buffer.baseAddress!
            )
        }

        guard copyStatus == kCMBlockBufferNoErr else {
            throw WaveformGenerationError.readerFailed
        }

        let presentationTime = CMTimeGetSeconds(
            CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        )
        guard presentationTime.isFinite else {
            throw WaveformGenerationError.readerFailed
        }

        return DecodedPCMBuffer(
            bytes: pcmBytes,
            channelsCount: channelsCount,
            bytesPerFrame: bytesPerFrame,
            sampleRate: sampleRate,
            presentationTime: presentationTime,
            framesCount: framesCount
        )
    }

    /// Возвращает вклад кадра в RMS по наибольшей амплитуде среди его каналов.
    private func squaredAmplitude(
        for frameIndex: Int,
        in pcmBuffer: DecodedPCMBuffer
    ) -> Double {
        let frameOffset = frameIndex * pcmBuffer.bytesPerFrame
        var frameAmplitude = 0.0

        for channelIndex in 0..<pcmBuffer.channelsCount {
            let sampleOffset = frameOffset + channelIndex * MemoryLayout<Int16>.size
            let amplitude = amplitude(
                fromLittleEndianBytesAt: sampleOffset,
                in: pcmBuffer.bytes
            )
            frameAmplitude = max(frameAmplitude, amplitude)
        }

        return frameAmplitude * frameAmplitude
    }

    /// Преобразует один signed 16-bit little-endian PCM-сэмпл в амплитуду от 0 до 1.
    private func amplitude(
        fromLittleEndianBytesAt offset: Int,
        in bytes: [UInt8]
    ) -> Double {
        let bitPattern = UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
        let signedSample = Int16(bitPattern: bitPattern)
        let normalized = abs(Double(signedSample)) / Double(Int16.max)
        return min(normalized, 1)
    }

    // MARK: - Нормализация

    /// Нормализует RMS каждого окна по наибольшему значению, сохраняя контракт кэша от 0 до 1.
    private func normalizedSamples(_ rootMeanSquares: [Double]) -> [Double] {
        guard let maximumAmplitude = rootMeanSquares.max(), maximumAmplitude > 0 else {
            return Array(repeating: 0, count: rootMeanSquares.count)
        }

        return rootMeanSquares.map { amplitude in
            min(max(amplitude / maximumAmplitude, 0), 1)
        }
    }

    /// Сводит суммы амплитуд последовательного пути к общему контракту нормализации.
    private func normalizedSamples(
        squaredAmplitudeSums: [Double],
        frameCounts: [Int]
    ) -> [Double] {
        let rootMeanSquares = zip(squaredAmplitudeSums, frameCounts).map { sum, count in
            guard count > 0 else { return 0.0 }
            return sqrt(sum / Double(count))
        }

        return normalizedSamples(rootMeanSquares)
    }
}

/// Хранит единственный короткий PCM-буфер, полученный от AVAssetReader.
private struct DecodedPCMBuffer {
    let bytes: [UInt8]
    let channelsCount: Int
    let bytesPerFrame: Int
    let sampleRate: Double
    let presentationTime: Double
    let framesCount: Int
}

/// Накапливает RMS одного окна, не создавая массив значений для каждого PCM-кадра.
private struct PCMContribution {
    private(set) var squaredAmplitudeSum = 0.0
    private(set) var framesCount = 0

    mutating func add(squaredAmplitude: Double) {
        squaredAmplitudeSum += squaredAmplitude
        framesCount += 1
    }
}
