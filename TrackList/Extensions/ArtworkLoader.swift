//
//  ArtworkLoader.swift
//  TrackList
//
//  Утилита для ленивой загрузки обложек в списках
//
//  Created by Pavel Fomin on 04.08.2025.
//

import Foundation
import UIKit

// Глобальный ограничитель параллельных декодирований
actor _ArtworkDecodeGate {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    init(value: Int) { self.value = value }

    func wait() async {
        if value > 0 { value -= 1; return }
        await withCheckedContinuation { cont in waiters.append(cont) }
    }

    func signal() {
        if !waiters.isEmpty {
            let c = waiters.removeFirst()
            c.resume()
        } else {
            value += 1
        }
    }
}

enum ArtworkLoader {

    static let decodeGate = _ArtworkDecodeGate(value: 2)

    // MARK: - Основной загрузчик через trackId

    static func loadIfNeeded(current: CGImage?, trackId: UUID) async -> CGImage? {
        if let current { return current }

        // 1) получаем URL из TrackRegistry
        guard let url = await BookmarkResolver.url(forTrack: trackId) else {
            return nil
        }
        
        // 2) обычная ленивая загрузка
        await decodeGate.wait()
        defer { Task { await decodeGate.signal() } }

        return await TrackMetadataCacheManager.shared.loadArtworkThrottled(url: url) {
            if let cached = TrackMetadataCacheManager.shared.loadMetadataFromCache(url: url)?.artwork {
                return cached
            }
            return await TrackMetadataCacheManager.shared.loadMetadata(for: url)?.artwork
        }
    }

    // MARK: - Отмена загрузки

    static func cancelLoad(trackId: UUID) async {
        guard let url = await BookmarkResolver.url(forTrack: trackId) else {
            return
        }
    }
}
