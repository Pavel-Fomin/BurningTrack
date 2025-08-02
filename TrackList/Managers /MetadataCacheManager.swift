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
import AVFoundation

@MainActor
final class TrackMetadataCacheManager: @unchecked Sendable {
    static let shared = TrackMetadataCacheManager()

    private let cache = NSCache<NSURL, CachedMetadata>()
    private var activeRequests: [URL: Task<TrackMetadata?, Never>] = [:]
    private let semaphore = AsyncSemaphore(value: 4)

    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 30 * 1024 * 1024 // 30 MB
    }

    func loadMetadata(for url: URL) async -> CachedMetadata? {
        let nsurl = url as NSURL

        // Если есть в кэше — отдать
        if let cached = cache.object(forKey: nsurl) {
            return cached
        }

        // Если уже идёт задача — дождаться
        if let existing = activeRequests[url] {
            if let result = await existing.value {
                let converted = convert(result)
                cache.setObject(converted, forKey: nsurl)
                return converted
            }
            return nil
        }

        // Новая задача
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
            let converted = convert(result)
            cache.setObject(converted, forKey: nsurl)
            return converted
        }

        return nil
    }

    private func convert(_ result: TrackMetadata) -> CachedMetadata {
        let image = result.artworkData.flatMap { UIImage(data: $0) }
        return CachedMetadata(title: result.title, artist: result.artist, artwork: image)
    }

    final class CachedMetadata: NSObject, @unchecked Sendable {
        let title: String?
        let artist: String?
        let artwork: UIImage?

        init(title: String?, artist: String?, artwork: UIImage?) {
            self.title = title
            self.artist = artist
            self.artwork = artwork
        }
    }
}

// MARK: - AsyncSemaphore

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
