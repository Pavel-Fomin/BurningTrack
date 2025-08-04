//
//  MetadataCacheManager.swift
//  TrackList
//
//  Оптимизированный кэш метаданных с NSCache и защитой доступа
//
//  Created by Pavel Fomin on 02.08.2025.
//

import Foundation
import UIKit
import AVFoundation

@MainActor
final class TrackMetadataCacheManager: @unchecked Sendable {
    static let shared = TrackMetadataCacheManager()
    
    // Основной кэш для хранения метаданных (NSCache для автоматического сброса при нехватке памяти)
    private let cache = NSCache<NSURL, CachedMetadata>()
    
    // Активные задачи загрузки метаданных, чтобы не дублировать запросы
    private var activeRequests: [URL: Task<TrackMetadata?, Never>] = [:]
    
    // Семафор для ограничения одновременных запросов (например, до 4 задач параллельно)
    private let semaphore = AsyncSemaphore(value: 4)
    
    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 30 * 1024 * 1024 // 30 MB
    }
    
    
// MARK: - Загрузка обложек
    
    /// Возвращает UIImage для заданного URL, либо из кэша, либо запрашивает метаданные
    func loadArtwork(for url: URL) async -> UIImage? {
        let nsurl = url as NSURL

        // Если уже есть в кэше — достаём CGImage и оборачиваем в UIImage
        if let cached = cache.object(forKey: nsurl), let cgImage = cached.artwork {
            return UIImage(cgImage: cgImage)
        }

        // Иначе пробуем загрузить метаданные, в том числе artwork
        if let metadata = await loadMetadata(for: url), let cgImage = metadata.artwork {
            return UIImage(cgImage: cgImage)
        }

        return nil
    }
    
    
// MARK: - Загрузка тегов
    
    /// Загружает и кэширует метаданные (теги и обложку)
    func loadMetadata(for url: URL) async -> CachedMetadata? {
        let nsurl = url as NSURL

        // Уже закэшировано
        if let cached = cache.object(forKey: nsurl) {
            return cached
        }

        // Если задача уже выполняется — дожидаемся результата
        if let existing = activeRequests[url] {
            if let result = await existing.value {
                return convertAndCache(result, for: nsurl)
            }
            return nil
        }

        // Новая задача загрузки
        let task = Task<TrackMetadata?, Never> {
            await semaphore.wait()
            defer { Task { await semaphore.signal() } }

            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            return try? await MetadataParser.parseMetadata(from: url)
        }

        activeRequests[url] = task
        let result = await task.value
        activeRequests[url] = nil

        if let result {
            return convertAndCache(result, for: nsurl)
        }
        return nil
        
        }

    /// Преобразует UIImage в CGImage и упаковывает в CachedMetadata
    private func convert(from image: UIImage, metadata: TrackMetadata) -> CachedMetadata {
        if let cgImage = image.cgImage {
    
            return CachedMetadata(title: metadata.title, artist: metadata.artist, artwork: cgImage)
        }

        return CachedMetadata(title: metadata.title, artist: metadata.artist, artwork: nil)
    }
    
    /// Обработка и кэширование результата парсинга
    private func convertAndCache(_ metadata: TrackMetadata, for nsurl: NSURL) -> CachedMetadata {
        if let original = metadata.artworkData.flatMap({ UIImage(data: $0) }) {
            let resized = normalize(original).resized(to: 48)
            let converted = convert(from: resized, metadata: metadata)

            // Оценка стоимости изображения в байтах (ш × в × 4 байта/px)
            let pixelWidth = Int(resized.size.width * resized.scale)
            let pixelHeight = Int(resized.size.height * resized.scale)
            let cost = pixelWidth * pixelHeight * 4

            cache.setObject(converted, forKey: nsurl, cost: cost)
            return converted
        } else {
            let fallback = CachedMetadata(title: metadata.title, artist: metadata.artist, artwork: nil)
            cache.setObject(fallback, forKey: nsurl, cost: 1)
            return fallback
        }
    }
    
    
    // MARK: - Внутренний тип, представляющий закэшированные метаданные
    
    final class CachedMetadata: NSObject, @unchecked Sendable {
        let title: String?
        let artist: String?
        let artwork: CGImage?

        init(title: String?, artist: String?, artwork: CGImage?) {
            self.title = title
            self.artist = artist
            self.artwork = artwork
        }
    }
    


// MARK: - Асинхронный семафор для ограничения количества параллельных задач

    actor AsyncSemaphore {
        private var value: Int
        private var waiters: [CheckedContinuation<Void, Never>] = []
        
        init(value: Int) {
            self.value = value
        }
        
        func wait() async {
            if value > 0 {
                value -= 1
                return
            }
            
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
        
        func signal() async {
            if let first = waiters.first {
                waiters.removeFirst()
                first.resume()
            } else {
                value += 1
            }
        }
        
    }
}
