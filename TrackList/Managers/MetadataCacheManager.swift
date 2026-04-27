//
//  MetadataCacheManager.swift
//  TrackList
//
//  Технический runtime-кэш сырых метаданных с NSCache и защитой доступа.
//  Используется как внутренний слой чтения для сборки TrackRuntimeSnapshot.
//
//  Created by Pavel Fomin on 02.08.2025.
//

import Foundation
import Combine

final class TrackMetadataCacheManager: ObservableObject, @unchecked Sendable {
    static let shared = TrackMetadataCacheManager()

    @Published private(set) var revision: Int = 0

    private let cache = NSCache<NSURL, CachedMetadata>()

    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 30 * 1024 * 1024 // 30 MB
    }
    
    
    // MARK: -  Быстрый доступ к кэшу без запуска парсинга
    
    /// Возвращает сырые метаданные из технического кэша без чтения файла.
    ///
    /// Важно:
    /// - не является источником истины для UI
    /// - используется только как быстрый доступ к уже загруженным данным
    func loadMetadataFromCache(url: URL) -> CachedMetadata? {
        cache.object(forKey: url as NSURL)
    }
    
    // MARK: - Инвалидация кэша

    /// Удаляет метаданные трека из технического кэша.
    /// Используется после изменения тегов, обложки или переименования файла.
    func invalidate(url: URL) {
        let nsurl = url as NSURL
        cache.removeObject(forKey: nsurl)

        Task {
            await _MetadataCoordinator.shared.cancel(url: url)

            await MainActor.run {
                self.revision += 1
            }
        }
    }

    /// Полная очистка кэша (например, при смене папки фонотеки).
    func invalidateAll() {
        cache.removeAllObjects()

        Task { @MainActor in
            self.revision += 1
        }
    }
    
    // MARK: - Загрузка тегов
    
    /// Загружает и кэширует сырые runtime-метаданные файла.
    ///
    /// Важно:
    /// - этот метод не является UI-контрактом
    /// - каноничная модель для экранов собирается отдельно в TrackRuntimeSnapshot
    func loadMetadata(for url: URL, includeArtwork: Bool = true) async -> CachedMetadata? {
        let nsurl = url as NSURL
        
        if let cached = cache.object(forKey: nsurl) {
            return cached
        }
        
        return await _MetadataCoordinator.shared.run(url: url) {
            guard let metadata = try? await RuntimeMetadataParser.parseMetadata(from: url) else { return nil }
            return self.convertAndCache(metadata, for: nsurl, includeArtwork: includeArtwork)
        }
    }
    
    
    // MARK: - Обработка и кэширование результата парсинга (с duration)
    
    private func convertAndCache(
        _ metadata: TrackMetadata,
        for nsurl: NSURL,
        includeArtwork: Bool
    ) -> CachedMetadata {
        
        // Обложка сохраняется в технический кэш только если она была запрошена.
        let cachedArtworkData = includeArtwork ? metadata.artworkData : nil
        
        let cached = CachedMetadata(
            title: metadata.title,
            artist: metadata.artist,
            duration: metadata.duration,
            artworkData: cachedArtworkData
        )
        
        // Стоимость считаем по размеру реально сохранённых данных, если они есть
        let cost = cachedArtworkData?.count ?? 1
        cache.setObject(cached, forKey: nsurl, cost: cost)
        
        return cached
    }
    
    
    // MARK: - Внутренний тип, представляющий закэшированные метаданные
    
    final class CachedMetadata: NSObject, @unchecked Sendable {
        
        let title: String?    /// Название
        let artist: String?   /// Исполнитель
        let duration: Double? /// Длительность
        
        /// Сырые данные обложки (JPEG / PNG и т.п.)
        /// - технический raw-cache, а не главный источник истины для UI
        /// - не декодируется здесь
        /// - не даунсемплится здесь
        /// - используется при сборке TrackRuntimeSnapshot и ArtworkProvider'ом
        let artworkData: Data?
        
        init(
            title: String?,
            artist: String?,
            duration: Double?,
            artworkData: Data?
        ) {
            self.title = title
            self.artist = artist
            self.duration = duration
            self.artworkData = artworkData
        }
    }
    
    // MARK: - Встроенный лимитер и дедуп загрузок
    
    /// Семафор для ограничения параллельного парсинга метаданных.
    /// Используется MetadataCoordinator'ом для дедупликации и троттлинга.
    actor _MetadataSemaphore {
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
    
    actor _MetadataCoordinator {
        static let shared = _MetadataCoordinator()
        
        private let sem = _MetadataSemaphore(value: 6)
        private var inFlight: [URL: Task<CachedMetadata?, Never>] = [:]
        
        private func finish(_ url: URL) {
            inFlight[url] = nil
        }
        
        func run(
            url: URL,
            job: @escaping () async -> CachedMetadata?
        ) async -> CachedMetadata? {
            
            if let task = inFlight[url] {
                return await task.value
            }
            
            await sem.acquire()
            
            let task = Task<CachedMetadata?, Never> {
                let result = await job()
                self.finish(url)
                await sem.release()
                return result
            }
            
            inFlight[url] = task
            return await task.value
        }
        
        func cancel(url: URL) {
            inFlight[url]?.cancel()
            inFlight[url] = nil
        }
    }
}
