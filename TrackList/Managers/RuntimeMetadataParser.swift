//
//  RuntimeMetadataParser.swift
//  TrackList
//
//  Парсер тегов и длительности трека
//  Использует AVFoundation и обёртку над TagLib
//
//  Created by Pavel Fomin on 23.04.2025.
//

import Foundation
import AVFoundation


// MARK: - Модель для хранения распарсенных метаданных трека

struct TrackMetadata {
    let artist: String?
    let title: String?
    let album: String?
    let artworkData: Data?
    let artworkSourceIdentifier: ArtworkSourceIdentifier?
    let duration: TimeInterval?
    let isCustomFormat: Bool
}


// MARK: - Основной парсер метаданных

/// Асинхронный парсер метаданных трека
/// Получает длительность через AVAsset и передаёт URL в TLTagLibFile для разбора тегов
final class RuntimeMetadataParser {
     
    static func parseMetadata(from url: URL) async throws -> TrackMetadata {
        let asset = AVURLAsset(url: url)
        
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        let metadata = TLTagLibFile(fileURL: url).readMetadata(duration: durationSeconds)

        // Хеш вычисляется в metadata-подготовке один раз и не попадает в SwiftUI View.
        return TrackMetadata(
            artist: metadata.artist,
            title: metadata.title,
            album: metadata.album,
            artworkData: metadata.artworkData,
            artworkSourceIdentifier: metadata.artworkData.map {
                ArtworkSourceIdentifier.embeddedArtwork(data: $0)
            },
            duration: metadata.duration,
            isCustomFormat: metadata.isCustomFormat
        )
    }
}
