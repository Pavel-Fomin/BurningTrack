//
//  LazyArtworkLoading.swift
//  TrackList
//
//  Утилита для ленивой загрузки обложек в списках
//
//  Created by Pavel Fomin on 04.08.2025.
//

import SwiftUI


enum ArtworkLoader {
    static func loadIfNeeded(current: CGImage?, url: URL) async -> CGImage? {
        if let current {
            return current
        }
        
        print("🎨 Обложка для \(url.lastPathComponent)")
        
        return await TrackMetadataCacheManager.shared
            .loadMetadata(for: url)?
            .artwork
    }
}
