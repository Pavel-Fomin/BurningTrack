//
//  MetadataParser.swift
//  TrackList
//
//  Парсер тегов и длительности трека
//  Использует AVFoundation и обёртку над TagLib
//
//  Created by Pavel Fomin on 23.04.2025.
//

import Foundation
import AVFoundation
import UIKit


// MARK: - Модель для хранения распарсенных метаданных трека

struct TrackMetadata {
    let artist: String?          /// Исполнитель
    let title: String?           /// Название
    let album: String?           /// Альбом
    let artworkData: Data?       /// Обложка в виде raw-данных
    let duration: TimeInterval?  /// Длительность трека в секундах
    let isCustomFormat: Bool     /// True, если использовалась кастомная библиотека (например, TagLib)
}


// MARK: - Основной парсер метаданных

/// Асинхронный парсер метаданных трека
/// Получает длительность через AVAsset и передаёт URL в TLTagLibFile для разбора тегов
final class MetadataParser {
    
    // не используется, но оставлен для совместимости
    static let shared = MetadataParser()
    
    /// Извлекает длительность (через AVFoundation) и метаданные (через TagLib)
    /// - Parameter url: Путь к аудиофайлу
    /// - Returns: TrackMetadata со всеми доступными полями
    static func parseMetadata(from url: URL) async throws -> TrackMetadata {
        let asset = AVURLAsset(url: url)
        
        // Получаем длительность файла асинхронно через AVAsset
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        // Парсим остальные теги через обёртку TLTagLibFile (TagLib)
        return TLTagLibFile(fileURL: url).readMetadata(duration: durationSeconds)
    }
    
    /// Извлекает только обложку из аудиофайла
    /// Использует TagLib и возвращает UIImage или nil
    static func extractArtwork(from url: URL) -> UIImage? {
        let metadata = TLTagLibFile(fileURL: url).readMetadata(duration: nil)
        guard let data = metadata.artworkData else { return nil }
        return UIImage(data: data)
    }
}
