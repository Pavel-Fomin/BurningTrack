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
import ImageIO


final class TrackMetadataCacheManager: @unchecked Sendable {
    static let shared = TrackMetadataCacheManager()
    
    
    // Основной кэш для хранения метаданных (NSCache для автоматического сброса при нехватке памяти)
    private let cache = NSCache<NSURL, CachedMetadata>()
    
    // Активные задачи загрузки метаданных, чтобы не дублировать запросы
    private let activeRequests = MetadataRequests()
    
    // Семафор для ограничения одновременных запросов (например, до 4 задач параллельно)
    private let semaphore = AsyncSemaphore(value: 1)
    
    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 30 * 1024 * 1024 // 30 MB
    }
    
    
    // MARK: -  Быстрый доступ к кэшу без запуска парсинга
    
    func loadMetadataFromCache(url: URL) -> CachedMetadata? {
        cache.object(forKey: url as NSURL)
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
        if let existing = await activeRequests.get(url) {
            if let result = await existing.value {
                return convertAndCache(result, for: nsurl)
            }
            return nil
        }

        let task = Task<TrackMetadata?, Never> {
            await semaphore.wait()
            defer { Task { await semaphore.signal() } }
            
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            
            return try? await MetadataParser.parseMetadata(from: url)
        }

        await activeRequests.set(url, task: task)
        let result = await task.value
        await activeRequests.clear(url)
        
        if let result {
            return convertAndCache(result, for: nsurl)
        }
        return nil
        
    }
    
    // Преобразует UIImage в CGImage и упаковывает в CachedMetadata (с duration)
    private func convert(from image: UIImage, metadata: TrackMetadata) -> CachedMetadata {
        if let cgImage = image.cgImage {
            return CachedMetadata(title: metadata.title,
                                  artist: metadata.artist,
                                  duration: metadata.duration,
                                  artwork: cgImage)
        }
        return CachedMetadata(title: metadata.title,
                              artist: metadata.artist,
                              duration: metadata.duration,
                              artwork: nil)
    }


    // MARK: - Обработка и кэширование результата парсинга (с duration)
    
    private func convertAndCache(_ metadata: TrackMetadata, for nsurl: NSURL) -> CachedMetadata {
        if let data = metadata.artworkData {
            let maxPixel = Int(ceil(48 * UIScreen.main.scale))

            // 1) основной путь — быстрый даунсемплинг
            if let cg = downsampleArtwork(data, maxPixel: maxPixel) {
                let converted = CachedMetadata(title: metadata.title,
                                               artist: metadata.artist,
                                               duration: metadata.duration,
                                               artwork: cg)
                cache.setObject(converted, forKey: nsurl, cost: maxPixel * maxPixel * 4)
                return converted
            }

            // 2) fallback: обычный UIImage + normalize (если всё-таки декодируется)
            if let ui = UIImage(data: data) {
                let fixed = normalize(ui)
                if let cg = fixed.cgImage {
                    let converted = CachedMetadata(title: metadata.title,
                                                   artist: metadata.artist,
                                                   duration: metadata.duration,
                                                   artwork: cg)
                    cache.setObject(converted, forKey: nsurl, cost: maxPixel * maxPixel * 4)
                    return converted
                }
            }
        }

        // 3) отрицательный кэш: запоминаем, что арта нет/битый → не дёргать снова
        let fallback = CachedMetadata(title: metadata.title,
                                      artist: metadata.artist,
                                      duration: metadata.duration,
                                      artwork: nil)
        cache.setObject(fallback, forKey: nsurl, cost: 1)
        return fallback
    }
    
    
    // MARK: -   Быстрое даунсемплирование арта
    
    private func downsampleArtwork(_ data: Data, maxPixel: Int) -> CGImage? {
        let cfData = data as CFData
        guard let src = CGImageSourceCreateWithData(cfData, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
    }
    
    
 // MARK: - Внутренний тип, представляющий закэшированные метаданные
    
    final class CachedMetadata: NSObject, @unchecked Sendable {
        let title: String?
        let artist: String?
        let duration: Double?
        let artwork: CGImage?

        init(title: String?, artist: String?, duration: Double?, artwork: CGImage?) {
            self.title = title
            self.artist = artist
            self.duration = duration
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
    
    // MARK: - Встроенный лимитер и дедуп загрузок
    
    actor _ArtworkSemaphore {
        private var value: Int
        private var waiters: [CheckedContinuation<Void, Never>] = []
        init(value: Int) { self.value = max(0, value) }
        func acquire() async {
            if value > 0 { value -= 1; return }
            await withCheckedContinuation { waiters.append($0) }
        }
        func release() async {
            if let c = waiters.first { waiters.removeFirst(); c.resume() }
            else { value += 1 }
        }
    }
    
    actor _ArtworkCoordinator {
        static let shared = _ArtworkCoordinator()
        
        private let sem = _ArtworkSemaphore(value: 6)
        private var inFlight: [URL: Task<CGImage?, Never>] = [:]
        
        private func finish(_ url: URL) {
            inFlight[url] = nil
        }
        
        func run(url: URL, job: @escaping () async -> CGImage?) async -> CGImage? {
            if let t = inFlight[url] { return await t.value } // дедуп: ждём существующую
            await sem.acquire()
            let t = Task<CGImage?, Never> {
                let result = await job()
                self.finish(url)     // свой актор — await не нужен
                await sem.release()  // чужой актор — await обязателен
                return result
            }
            
            inFlight[url] = t
            return await t.value
        }
        
        func cancel(url: URL) {
            inFlight[url]?.cancel()
            inFlight[url] = nil
        }
    }
}
    
    // MARK: - Фасады внутри кэша:
    
    extension TrackMetadataCacheManager {
        func loadArtworkThrottled(url: URL, build: @escaping () async -> CGImage?) async -> CGImage? {
            await _ArtworkCoordinator.shared.run(url: url, job: build)
        }
        func cancelArtworkLoad(url: URL) {
            Task { await _ArtworkCoordinator.shared.cancel(url: url) }
        }
    }


actor MetadataRequests {
    private var requests: [URL: Task<TrackMetadata?, Never>] = [:]
    
    func get(_ url: URL) -> Task<TrackMetadata?, Never>? {
        requests[url]
    }
    
    func set(_ url: URL, task: Task<TrackMetadata?, Never>) {
        requests[url] = task
    }
    
    func clear(_ url: URL) {
        requests[url] = nil
    }
}
