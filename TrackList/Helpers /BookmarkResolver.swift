//
//  BookmarkResolver.swift
//  TrackList
//
//  Нормализованный доступ к реальным URL треков и папок.
//  Работает поверх BookmarksRegistry.
//  TrackRegistry хранит только метаданные.
//
//  Created by Pavel Fomin on 01.12.2025.
//

import Foundation

enum BookmarkResolver {

    static func url(forTrack id: UUID) async -> URL? {
        // 1. Получаем base64 bookmark
        guard let base64 = await BookmarksRegistry.shared.trackBookmark(for: id),
              let data = Data(base64Encoded: base64) else {
            return nil
        }

        // 2. Резолвим в URL
        var stale = false
        return try? URL(
            resolvingBookmarkData: data,
            options: [.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
    }

    static func url(forFolder id: UUID) async -> URL? {
        guard let base64 = await BookmarksRegistry.shared.folderBookmark(for: id),
              let data = Data(base64Encoded: base64) else {
            return nil
        }

        var stale = false
        return try? URL(
            resolvingBookmarkData: data,
            options: [.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
    }
}
