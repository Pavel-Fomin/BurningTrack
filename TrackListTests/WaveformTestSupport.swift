//
//  WaveformTestSupport.swift
//  TrackList
//
//  Вспомогательные локальные WAV-файлы для проверки waveform без мини-плеера.
//
//  Created by Pavel Fomin on 28.07.2026.
//

import Foundation

/// Создаёт минимальные локальные WAV-файлы с управляемыми PCM-амплитудами для unit-тестов.
enum WaveformTestFileFactory {

    /// Создаёт изолированный каталог, который тест удаляет после проверки.
    static func makeDirectory(named name: String) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        return directoryURL
    }

    /// Записывает mono WAV с равными по длине сегментами заданной PCM-амплитуды.
    static func makeWaveFile(
        in directoryURL: URL,
        named fileName: String,
        segmentAmplitudes: [Int16],
        framesPerSegment: Int,
        sampleRate: UInt32 = 8_000
    ) throws -> URL {
        let fileURL = directoryURL.appendingPathComponent(fileName, isDirectory: false)
        let samples = segmentAmplitudes.flatMap { amplitude in
            Array(repeating: amplitude, count: framesPerSegment)
        }
        let dataSize = samples.count * MemoryLayout<Int16>.size

        var waveData = Data()
        waveData.append(contentsOf: Array("RIFF".utf8))
        appendLittleEndian(UInt32(36 + dataSize), to: &waveData)
        waveData.append(contentsOf: Array("WAVE".utf8))
        waveData.append(contentsOf: Array("fmt ".utf8))
        appendLittleEndian(UInt32(16), to: &waveData)
        appendLittleEndian(UInt16(1), to: &waveData)
        appendLittleEndian(UInt16(1), to: &waveData)
        appendLittleEndian(sampleRate, to: &waveData)
        appendLittleEndian(sampleRate * 2, to: &waveData)
        appendLittleEndian(UInt16(2), to: &waveData)
        appendLittleEndian(UInt16(16), to: &waveData)
        waveData.append(contentsOf: Array("data".utf8))
        appendLittleEndian(UInt32(dataSize), to: &waveData)

        for sample in samples {
            appendLittleEndian(UInt16(bitPattern: sample), to: &waveData)
        }

        try waveData.write(to: fileURL, options: .atomic)
        return fileURL
    }

    /// Создаёт обычный локальный файл для проверок ключа файлового кэша без декодирования аудио.
    static func makeRegularFile(
        in directoryURL: URL,
        named fileName: String,
        contents: Data
    ) throws -> URL {
        let fileURL = directoryURL.appendingPathComponent(fileName, isDirectory: false)
        try contents.write(to: fileURL, options: .atomic)
        return fileURL
    }

    /// Добавляет беззнаковое little-endian значение в бинарный WAV-контейнер.
    private static func appendLittleEndian<Value: FixedWidthInteger>(
        _ value: Value,
        to data: inout Data
    ) {
        var littleEndianValue = value.littleEndian
        withUnsafeBytes(of: &littleEndianValue) { bytes in
            data.append(contentsOf: bytes)
        }
    }
}
