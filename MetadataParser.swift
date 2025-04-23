//
//  MetadataParser.swift
//  TrackList
//
//  Created by Pavel Fomin on 23.04.2025.
//

import Foundation
import AVFoundation
import UIKit

struct TrackMetadata {
    let artist: String?
    let title: String?
    let album: String?
    let artworkData: Data?
}

enum AudioFormat {
    case mp3, flac, wav, aiff, alac, unknown
}

class MetadataParser {
    static func parseMetadata(from url: URL) throws -> TrackMetadata {
        let format = detectFormat(for: url)
        
        switch format {
        case .mp3, .alac:
            return parseWithAVFoundation(from: url)
        case .flac:
            return try parseFlacVorbisComments(from: url)
        case .wav, .aiff:
            // Пока не реализовано, можно расширить потом
            return TrackMetadata(artist: nil, title: nil, album: nil, artworkData: nil)
        case .unknown:
            return TrackMetadata(artist: nil, title: nil, album: nil, artworkData: nil)
        }
    }

    private static func detectFormat(for url: URL) -> AudioFormat {
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else { return .unknown }
        defer { try? fileHandle.close() }
        let magic = try? fileHandle.read(upToCount: 4)

        guard let bytes = magic else { return .unknown }

        if bytes == Data([0x66, 0x4C, 0x61, 0x43]) { // "fLaC"
            return .flac
        } else if bytes.starts(with: [0x52, 0x49, 0x46, 0x46]) { // "RIFF"
            return .wav
        } else if bytes.starts(with: [0x46, 0x4F, 0x52, 0x4D]) { // "FORM"
            return .aiff
        } else if bytes.starts(with: [0x49, 0x44, 0x33]) { // "ID3"
            return .mp3
        } else if bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0 { // MPEG frame sync
            return .mp3
        } else {
            return .unknown
        }
    }

    private static func parseWithAVFoundation(from url: URL) -> TrackMetadata {
        let asset = AVURLAsset(url: url)
        let artist = asset.commonMetadata.first(where: { $0.commonKey?.rawValue == "artist" })?.stringValue
        let title = asset.commonMetadata.first(where: { $0.commonKey?.rawValue == "title" })?.stringValue
        let album = asset.commonMetadata.first(where: { $0.commonKey?.rawValue == "album" })?.stringValue
        let artworkData = AVMetadataItem.metadataItems(from: asset.commonMetadata, withKey: AVMetadataKey.commonKeyArtwork, keySpace: .common).first?.dataValue
        return TrackMetadata(artist: artist, title: title, album: album, artworkData: artworkData)
    }

    private static func parseFlacVorbisComments(from url: URL) throws -> TrackMetadata {
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { try? fileHandle.close() }

        let header = try fileHandle.read(upToCount: 4)
        guard header == Data([0x66, 0x4C, 0x61, 0x43]) else {
            throw NSError(domain: "MetadataParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not a FLAC file"])
        }

        var artist: String?
        var title: String?
        var album: String?
        var artworkData: Data? = nil

        var isLastBlock = false
        while !isLastBlock {
            guard let blockHeader = try fileHandle.read(upToCount: 4) else { break }
            let blockType = blockHeader[0] & 0x7F
            isLastBlock = (blockHeader[0] & 0x80) != 0
            let blockSize = Int(blockHeader[1]) << 16 | Int(blockHeader[2]) << 8 | Int(blockHeader[3])

            if blockType == 4 { // VORBIS_COMMENT
                let blockData = try fileHandle.read(upToCount: blockSize) ?? Data()
                let comments = try parseVorbisCommentBlock(blockData)
                artist = comments["ARTIST"] ?? comments["artist"]
                title = comments["TITLE"] ?? comments["title"]
                album = comments["ALBUM"] ?? comments["album"]
            } else if blockType == 6 { // PICTURE
                artworkData = try? parsePictureBlock(from: fileHandle, blockSize: blockSize)
            } else {
                try fileHandle.seek(toOffset: fileHandle.offsetInFile + UInt64(blockSize))
            }
        }

        return TrackMetadata(artist: artist, title: title, album: album, artworkData: artworkData)
    }

    private static func parseVorbisCommentBlock(_ data: Data) throws -> [String: String] {
        var tags: [String: String] = [:]
        var offset = 0

        func readUInt32() throws -> UInt32 {
            guard offset + 4 <= data.count else {
                throw NSError(domain: "MetadataParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "Corrupted Vorbis comment block"])
            }
            let range = offset..<(offset + 4)
            let value = data.subdata(in: range).withUnsafeBytes { $0.load(as: UInt32.self) }
            offset += 4
            return UInt32(littleEndian: value)
        }

        let vendorLength = Int(try readUInt32())
        offset += vendorLength

        _ = Int(try readUInt32())

        let maxSafeOffset = min(data.count, offset + 5_000_000) // 5 MB limit

        while offset + 4 <= maxSafeOffset {
            let commentLength = Int(try readUInt32())
            if offset + commentLength > maxSafeOffset {
                print("🚩 Suspiciously large comment, skipping the rest")
                break
            }

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

    private static func parsePictureBlock(from fileHandle: FileHandle, blockSize: Int) throws -> Data {
        let blockData = try fileHandle.read(upToCount: blockSize) ?? Data()
        var offset = 0

        func readUInt32() -> UInt32 {
            guard offset + 4 <= blockData.count else {
                fatalError("Corrupted picture block: insufficient data while reading UInt32 (offset: \(offset))")
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

        _ = readUInt32()                        // picture type
        let mimeLength = Int(readUInt32())
        _ = readData(length: mimeLength)        // MIME type
        let descLength = Int(readUInt32())
        _ = readData(length: descLength)        // description
        _ = readUInt32()                        // width
        _ = readUInt32()                        // height
        _ = readUInt32()                        // color depth
        _ = readUInt32()                        // colors used

        let pictureDataLength = Int(readUInt32())
        let pictureData = readData(length: pictureDataLength)

        return pictureData
    }
}
