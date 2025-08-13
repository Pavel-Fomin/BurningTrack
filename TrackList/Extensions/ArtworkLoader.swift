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

// Глобальный ограничитель параллельных декодирований (каппим CPU)
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
    // Максимум 3 одновременных декодирования/ресайза
    static let decodeGate = _ArtworkDecodeGate(value: 2)

    static func loadIfNeeded(current: CGImage?, url: URL, priorityList: [URL] = []) async -> CGImage? {
        if let current { return current }

        // обычная ленивая загрузка с лимитом и дедупом
        await decodeGate.wait()
        defer { Task { await decodeGate.signal() } }

        return await TrackMetadataCacheManager.shared.loadArtworkThrottled(url: url) {
            if let cg = TrackMetadataCacheManager.shared.loadMetadataFromCache(url: url)?.artwork {
                return cg
            }
            return await TrackMetadataCacheManager.shared.loadMetadata(for: url)?.artwork
        }
    }

    static func cancelLoad(for url: URL) {
        TrackMetadataCacheManager.shared.cancelArtworkLoad(url: url)
    }
}
