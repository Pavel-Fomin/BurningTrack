//
//  SecurityScopedBookmarkHelper.swift
//  TrackList
//
//  Вспомогательный хелпер для восстановления URL из bookmarkBase64
//
//  Created by Pavel Fomin on 02.08.2025.
//

import Foundation

enum SecurityScopedBookmarkHelper {
    
    /// Восстанавливает URL из base64 bookmarkData (без начала доступа)
    static func resolveURL(from base64: String) -> URL? {
        guard let data = Data(base64Encoded: base64) else { return nil }

        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
            return url
        } catch {
            print("❌ Не удалось восстановить URL из bookmarkBase64: \(error.localizedDescription)")
            return nil
        }
    }
}
