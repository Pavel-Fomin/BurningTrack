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
        cache.countLimit = 100
        cache.totalCostLimit = 30 * 1024 * 1024 // 30 MB

        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cache.removeAllObjects()
        }
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

            guard var image = MetadataParser.extractArtwork(from: url) else {
                completion(nil)
                return
            }

            image = image.resized(to: 48)

            if let cgImage = image.cgImage {
                let bytesPerPixel = 4
                let cost = cgImage.width * cgImage.height * bytesPerPixel
                self?.cache.setObject(image, forKey: nsURL, cost: cost)
            } else {
                self?.cache.setObject(image, forKey: nsURL)
            }
            completion(image)
        }
    }
    
    
    func cachedImage(for url: URL) -> UIImage? {
        return cache.object(forKey: url as NSURL)
    }
}
