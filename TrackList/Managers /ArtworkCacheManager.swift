//
//  ArtworkCacheManager.swift
//  TrackList
//
//  Created by Pavel Fomin on 31.07.2025.
//

import Foundation
import UIKit

final class ArtworkCacheManager {
    static let shared = ArtworkCacheManager()

    private let cache = NSCache<NSURL, UIImage>()
    private var activeRequests = Set<URL>()
    private let queue = DispatchQueue(label: "artwork.loader", qos: .userInitiated)

    private init() {
        
        // Опционально: ограничить размер кэша
        cache.countLimit = 100
        cache.totalCostLimit = 30 * 1024 * 1024 // 30 MB
    }

    /// Возвращает обложку из кэша или загружает её из файла
    func image(for url: URL, completion: @escaping (UIImage?) -> Void) {
        let nsURL = url as NSURL

        // Если есть в кэше — сразу вернуть
        if let cachedImage = cache.object(forKey: nsURL) {
            completion(cachedImage)
            return
        }

        // Если уже загружается — игнорируем
        guard !activeRequests.contains(url) else { return }
        activeRequests.insert(url)

        // Загрузка в фоне
        queue.async { [weak self] in
            defer { self?.activeRequests.remove(url) }

            guard let image = MetadataParser.extractArtwork(from: url) else {
                completion(nil)
                return
            }

            self?.cache.setObject(image, forKey: nsURL)
            completion(image)
        }
    }
    
    
    func cachedImage(for url: URL) -> UIImage? {
        return cache.object(forKey: url as NSURL)
    }
}
