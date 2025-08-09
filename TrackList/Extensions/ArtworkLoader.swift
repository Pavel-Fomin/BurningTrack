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

enum ArtworkLoader {
    static func loadIfNeeded(current: CGImage?, url: URL, priorityList: [URL] = []) async -> CGImage? {
        if let current { return current }

        // быстрый кэш
        if let cg = TrackMetadataCacheManager.shared.loadMetadataFromCache(url: url)?.artwork,
           cg.width > 0, cg.height > 0 {
            return cg
        }

        // если URL в приоритетных — грузим напрямую, без семафора
        if priorityList.contains(url) {
            if let cg = await TrackMetadataCacheManager.shared.loadMetadata(for: url)?.artwork {
                return cg
            }
            return nil
        }

        // обычная ленивая загрузка с лимитом и дедупом
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
