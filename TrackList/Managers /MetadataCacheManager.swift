//
//  MetadataCacheManager.swift
//  TrackList
//
//  Кэш для хранения метаданных и обложек треков
//
//  Created by Pavel Fomin on 02.08.2025.
//

import Foundation
import UIKit


final class TrackMetadataCacheManager {
    static let shared = TrackMetadataCacheManager()

    /// Внутренний кэш
    private let cache = NSCache<NSURL, CachedMetadata>()

    /// Активные задачи загрузки — чтобы не дублировать
    private var activeRequests = [URL: Task<CachedMetadata?, Never>]()

    private init() {
        cache.countLimit = 100
    }

    /// Возвращает кэшированные данные или запускает фоновую загрузку
    func loadMetadata(for url: URL) async -> CachedMetadata? {
        let nsurl = url as NSURL

        if let cached = cache.object(forKey: nsurl) {
            return cached
        }

        // Если задача уже активна — подождать её
        if let existingTask = activeRequests[url] {
            return await existingTask.value
        }

        // Создаём и сохраняем новую задачу
        let task = Task {
            let metadata = try? await MetadataParser.parseMetadata(from: url)

            let result = CachedMetadata(
                title: metadata?.title,
                artist: metadata?.artist,
                artwork: metadata?.artworkData.flatMap { UIImage(data: $0) }
            )

            if let result = result {
                cache.setObject(result, forKey: nsurl)
            }

            activeRequests[url] = nil
            return result
        }

        activeRequests[url] = task
        return await task.value
    }
}
