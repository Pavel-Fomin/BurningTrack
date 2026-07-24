//
//  TrackTechnicalMetadataReader.swift
//  TrackList
//
//  Асинхронное чтение технических свойств аудиофайла для runtime snapshot.
//
//  Created by Pavel Fomin on 24.07.2026.
//

import AudioToolbox
import AVFoundation
import Foundation

/// Читает технические данные вне MainActor и возвращает только достоверно доступные значения.
actor TrackTechnicalMetadataReader {

    // MARK: - Singleton

    /// Общий считыватель предотвращает чтение синхронных файловых свойств на главном потоке.
    static let shared = TrackTechnicalMetadataReader()

    // MARK: - Init

    private init() {}

    // MARK: - Read

    /// Получает размер, формат и битрейт из фактического URL аудиоисточника.
    /// - Parameter url: Локальный либо media-library URL доступного аудиоисточника.
    /// - Returns: Набор только тех значений, которые удалось надёжно прочитать.
    func metadata(for url: URL) async -> TrackTechnicalMetadata {
        let fileSizeBytes = fileSizeBytes(from: url)
        let fileFormat = fileFormat(from: url)
        let bitrateBitsPerSecond = await bitrateBitsPerSecond(from: url)

        return TrackTechnicalMetadata(
            fileSizeBytes: fileSizeBytes,
            fileFormat: fileFormat,
            bitrateBitsPerSecond: bitrateBitsPerSecond
        )
    }

    // MARK: - File properties

    /// Читает фактический размер только у URL, который система подтверждает как обычный файл.
    private func fileSizeBytes(from url: URL) -> Int64? {
        guard let values = try? url.resourceValues(
            forKeys: [.isRegularFileKey, .fileSizeKey]
        ),
            values.isRegularFile == true,
            let fileSize = values.fileSize
        else {
            return nil
        }

        return Int64(fileSize)
    }

    /// Получает формат напрямую из расширения текущего URL, не используя отображаемое имя файла.
    private func fileFormat(from url: URL) -> String? {
        let fileExtension = url.pathExtension.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard fileExtension.isEmpty == false else {
            return nil
        }

        return fileExtension.uppercased()
    }

    // MARK: - Audio track

    /// Сначала читает битрейт файла через Audio Toolbox, затем использует AVFoundation как резервный источник.
    private func bitrateBitsPerSecond(from url: URL) async -> Int? {
        // Для FLAC AVFoundation иногда возвращает estimatedDataRate == 0, поэтому он не может быть основным источником.
        if let audioToolboxBitrate = audioToolboxBitrateBitsPerSecond(from: url) {
            return audioToolboxBitrate
        }

        // AVFoundation остаётся резервом для media-library URL и форматов без свойства Audio Toolbox.
        return await avFoundationBitrateBitsPerSecond(from: url)
    }

    /// Читает средний битрейт аудиоданных напрямую через свойство Audio Toolbox.
    private func audioToolboxBitrateBitsPerSecond(from url: URL) -> Int? {
        var audioFile: AudioFileID?
        let openStatus = AudioFileOpenURL(
            url as CFURL,
            .readPermission,
            0,
            &audioFile
        )

        guard openStatus == noErr,
              let audioFile
        else {
            return nil
        }

        // Audio Toolbox владеет открытым AudioFileID, поэтому закрываем его при любом выходе из метода.
        defer {
            AudioFileClose(audioFile)
        }

        // В SDK iOS kAudioFilePropertyBitRate документирован как UInt32.
        var bitrate: UInt32 = 0
        var propertySize = UInt32(MemoryLayout<UInt32>.size)
        let propertyStatus = AudioFileGetProperty(
            audioFile,
            kAudioFilePropertyBitRate,
            &propertySize,
            &bitrate
        )
        let bitrateAsDouble = Double(bitrate)

        guard propertyStatus == noErr,
              propertySize == UInt32(MemoryLayout<UInt32>.size),
              bitrateAsDouble.isFinite,
              bitrateAsDouble > 0,
              bitrateAsDouble <= Double(Int.max)
        else {
            return nil
        }

        return Int(bitrateAsDouble)
    }

    /// Запрашивает AVFoundation оценку битрейта первой аудиодорожки, если Audio Toolbox не дал значения.
    private func avFoundationBitrateBitsPerSecond(from url: URL) async -> Int? {
        let asset = AVURLAsset(url: url)

        do {
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            guard let audioTrack = audioTracks.first else {
                return nil
            }

            let estimatedDataRate = try await audioTrack.load(.estimatedDataRate)
            let bitrate = Double(estimatedDataRate)

            guard bitrate.isFinite,
                  bitrate > 0,
                  bitrate <= Double(Int.max)
            else {
                return nil
            }

            return Int(bitrate)
        } catch {
            // Недоступный источник не препятствует отображению остальных технических свойств.
            return nil
        }
    }
}
