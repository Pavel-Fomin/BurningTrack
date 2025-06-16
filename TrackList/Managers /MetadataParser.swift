//
//  MetadataParser.swift
//  TrackList
//
//  Парсер тегов для .flac, .wav, .unknown
//
//  Created by Pavel Fomin on 23.04.2025.
//

import Foundation
import AVFoundation
import UIKit

// MARK: - Модель для хранения распарсенных метаданных трека

struct TrackMetadata {
    let artist: String?
    let title: String?
    let album: String?
    let artworkData: Data?
    let duration: TimeInterval?
    let isCustomFormat: Bool
}

// MARK: - Поддерживаемые форматы (определяются вручную по сигнатуре файла)

enum AudioFormat {
    case mp3, flac, wav, aiff, alac, unknown
}

// MARK: - Основной парсер метаданных

class MetadataParser {
    
    /// Определяет формат аудиофайла и парсит метаданные
    static func parseMetadata(from url: URL) async throws -> TrackMetadata {
        let format = detectFormat(for: url)
        print("Определён формат: \(format) для файла: \(url.lastPathComponent)")
        
        // Получаем длительность через AVAsset
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        print("Длительность (AVAsset): \(durationSeconds) сек")

        switch format {
        case .mp3, .alac:
            return await parseWithAVFoundation(from: url, duration: durationSeconds)
        case .flac:
            return try parseFlacVorbisComments(from: url, duration: durationSeconds)
        case .wav, .aiff, .unknown:
            return TrackMetadata(
                artist: nil,
                title: nil,
                album: nil,
                artworkData: nil,
                duration: durationSeconds,
                isCustomFormat: true
            )
        }
    }
    
    /// Определяет формат аудиофайла по сигнатуре
    private static func detectFormat(for url: URL) -> AudioFormat {
        guard url.startAccessingSecurityScopedResource() else {
            return .unknown
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let fileHandle = try? FileHandle(forReadingFrom: url) else { return .unknown }
        defer { try? fileHandle.close() }

        guard let bytes = try? fileHandle.read(upToCount: 4) else {
            return .unknown
        }

        if bytes == Data([0x66, 0x4C, 0x61, 0x43]) {
            return .flac
        } else if bytes.starts(with: [0x52, 0x49, 0x46, 0x46]) {
            return .wav
        } else if bytes.starts(with: [0x46, 0x4F, 0x52, 0x4D]) {
            return .aiff
        } else if bytes.starts(with: [0x49, 0x44, 0x33]) {
            return .mp3
        } else if bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0 {
            return .mp3
        } else {
            assertionFailure("Не удалось определить формат файла: \(url.lastPathComponent)")
            return .unknown
        }
    }

    /// Парсит теги с помощью AVFoundation (для MP3, ALAC)
    private static func parseWithAVFoundation(from url: URL, duration: TimeInterval?) async -> TrackMetadata {
        let asset = AVURLAsset(url: url)

        do {
            let metadata = try await asset.load(.commonMetadata)

            let artistItem = metadata.first(where: { $0.commonKey?.rawValue == "artist" })
            let titleItem  = metadata.first(where: { $0.commonKey?.rawValue == "title" })
            let albumItem  = metadata.first(where: { $0.commonKey?.rawValue == "album" })
            let artworkItem = AVMetadataItem.metadataItems(
                from: metadata,
                withKey: AVMetadataKey.commonKeyArtwork,
                keySpace: .common
            ).first

            let artist = try await artistItem?.load(.stringValue)
            let title  = try await titleItem?.load(.stringValue)
            let album  = try await albumItem?.load(.stringValue)
            let artworkData = try await artworkItem?.load(.dataValue)

            return TrackMetadata(
                artist: artist,
                title: title,
                album: album,
                artworkData: artworkData,
                duration: duration,
                isCustomFormat: false
            )

        } catch {
            print("Ошибка чтения метаданных AVFoundation: \(error)")
            return TrackMetadata(
                artist: nil,
                title: nil,
                album: nil,
                artworkData: nil,
                duration: duration,
                isCustomFormat: false
            )
        }
    }

    /// Парсит блоки VorbisComment и Picture в FLAC-файлах
    private static func parseFlacVorbisComments(from url: URL, duration: TimeInterval?) throws -> TrackMetadata {
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "MetadataParser", code: 401, userInfo: [NSLocalizedDescriptionKey: "Нет доступа к файлу"])
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { try? fileHandle.close() }

        let header = try fileHandle.read(upToCount: 4)
        guard header == Data([0x66, 0x4C, 0x61, 0x43]) else {
            throw NSError(domain: "MetadataParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Не FLAC-файл"])
        }

        var artist: String?
        var title: String?
        var album: String?
        var artworkData: Data? = nil

        var isLastBlock = false
        _ = try fileHandle.offset()

        while !isLastBlock {
            guard let blockHeader = try fileHandle.read(upToCount: 4) else { break }

            let blockType = blockHeader[0] & 0x7F
            isLastBlock = (blockHeader[0] & 0x80) != 0
            let blockSize = Int(blockHeader[1]) << 16 | Int(blockHeader[2]) << 8 | Int(blockHeader[3])

            switch blockType {
            case 4:
                let blockData = try fileHandle.read(upToCount: blockSize) ?? Data()
                let comments = try parseVorbisCommentBlock(blockData)
                artist = comments["ARTIST"] ?? comments["artist"]
                title  = comments["TITLE"]  ?? comments["title"]
                album  = comments["ALBUM"]  ?? comments["album"]
            case 6:
                artworkData = try? parsePictureBlock(from: fileHandle, blockSize: blockSize)
            default:
                try fileHandle.seek(toOffset: fileHandle.offsetInFile + UInt64(blockSize))
            }
        }

        return TrackMetadata(
            artist: artist,
            title: title,
            album: album,
            artworkData: artworkData,
            duration: duration ?? 0,
            isCustomFormat: true
        )
    }

    /// Разбор Vorbis-комментариев (key=value)
    private static func parseVorbisCommentBlock(_ data: Data) throws -> [String: String] {
        var tags: [String: String] = [:]
        var offset = 0

        func readUInt32() throws -> UInt32 {
            guard offset + 4 <= data.count else {
                throw NSError(domain: "MetadataParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "Повреждённый Vorbis-блок"])
            }
            let range = offset..<(offset + 4)
            let value = data.subdata(in: range).withUnsafeBytes { $0.load(as: UInt32.self) }
            offset += 4
            return UInt32(littleEndian: value)
        }

        let vendorLength = Int(try readUInt32())
        offset += vendorLength
        _ = Int(try readUInt32()) // Кол-во комментариев

        let maxOffset = min(data.count, offset + 5_000_000)

        while offset + 4 <= maxOffset {
            let commentLength = Int(try readUInt32())
            if offset + commentLength > maxOffset { break }

            let commentData = data.subdata(in: offset..<(offset + commentLength))
            offset += commentLength

            if let comment = String(data: commentData, encoding: .utf8),
               let equalIndex = comment.firstIndex(of: "=") {
                let key = comment[..<equalIndex].uppercased()
                let value = comment[comment.index(after: equalIndex)...]
                tags[String(key)] = String(value)
            }
        }

        return tags
    }

    /// Разбор бинарного PICTURE-блока для извлечения изображения
    private static func parsePictureBlock(from fileHandle: FileHandle, blockSize: Int) throws -> Data {
        let blockData = try fileHandle.read(upToCount: blockSize) ?? Data()
        var offset = 0

        func readUInt32() throws -> UInt32 {
            guard offset + 4 <= blockData.count else {
                throw NSError(domain: "MetadataParser", code: 100, userInfo: [NSLocalizedDescriptionKey: "Недостаточно данных в PICTURE-блоке (offset: \(offset))"])
            }
            let range = offset..<(offset + 4)
            let value = blockData.subdata(in: range).withUnsafeBytes { $0.load(as: UInt32.self) }
            offset += 4
            return UInt32(bigEndian: value)
        }

        func readData(length: Int) -> Data {
            let range = offset..<(offset + length)
            let data = blockData.subdata(in: range)
            offset += length
            return data
        }

        _ = try readUInt32()                         // picture type
        let mimeLength = Int(try readUInt32())
        _ = readData(length: mimeLength)             // MIME type
        let descLength = Int(try readUInt32())
        _ = readData(length: descLength)             // description
        _ = try readUInt32()                         // width
        _ = try readUInt32()                         // height
        _ = try readUInt32()                         // color depth
        _ = try readUInt32()                         // colors used

        let pictureDataLength = Int(try readUInt32())
        return readData(length: pictureDataLength)
    }
}
