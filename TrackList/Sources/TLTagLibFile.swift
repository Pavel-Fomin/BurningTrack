//
//  TLTagLibFile.swift
//  TrackList
//
//  Created by Pavel Fomin on 21.06.2025.
//

import Foundation

/// Обёртка над C++ API TagLib для чтения тегов
public class TLTagLibFile {
    private let filePath: String
    
    public init(fileURL: URL) {
        self.filePath = fileURL.path
    }
    
    /// Считанные теги из аудиофайла
    public struct ParsedMetadata {
        public let title: String?
        public let artist: String?
        public let album: String?
        public let genre: String?
        public let comment: String?
        public let artworkData: Data?
    }
    
    /// Основной метод чтения тегов
    public func readMetadata() -> ParsedMetadata? {
        guard let result = _readMetadata(filePath) else {
               return nil
        }

        return ParsedMetadata(
            title: result.title,
            artist: result.artist,
            album: result.album,
            genre: result.genre,
            comment: result.comment,
            artworkData: result.artworkData
        )
    }
    
    func readMetadata(duration: TimeInterval?) -> TrackMetadata {
        guard let parsed = readMetadata() else {
            return TrackMetadata(
                artist: nil,
                title: nil,
                album: nil,
                artworkData: nil,
                duration: duration,
                isCustomFormat: true
            )
        }

        return TrackMetadata(
            artist: parsed.artist,
            title: parsed.title,
            album: parsed.album,
            artworkData: parsed.artworkData,
            duration: duration,
            isCustomFormat: true
        )
    }
}
