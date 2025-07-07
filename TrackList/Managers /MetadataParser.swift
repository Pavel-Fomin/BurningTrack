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


// MARK: - Основной парсер метаданных

final class MetadataParser {
    static let shared = MetadataParser()
    
    // Асинхронно получает длительность через AVAsset и теги через TagLib
    static func parseMetadata(from url: URL) async throws -> TrackMetadata {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        return TLTagLibFile(fileURL: url).readMetadata(duration: durationSeconds)
    }
}
