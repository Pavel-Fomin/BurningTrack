//
//  LibraryTrack.swift
//  TrackList
//
//  Created by Pavel Fomin on 05.07.2025.
//

import Foundation
import UIKit

struct LibraryTrack: Identifiable, TrackDisplayable {
    var id: UUID { original.id }
    let url: URL                /// оставим для fallback
    let bookmarkBase64: String  /// добавляем
    var title: String?
    let artist: String?
    let duration: TimeInterval
    let artwork: UIImage?
    let addedDate: Date
    let original: ImportedTrack

    /// Имя файла без расширения (для отображения)
    var fileName: String {
        (try? resolveURL().deletingPathExtension().lastPathComponent) ?? url.deletingPathExtension().lastPathComponent
    }

    /// Проверка доступности файла
    var isAvailable: Bool {
        guard let resolved = try? resolveURL() else { return false }
        return FileManager.default.fileExists(atPath: resolved.path)
    }

    /// Восстанавливает URL из bookmarkBase64 (без старта доступа)
    func resolveURL() throws -> URL {
        guard let data = Data(base64Encoded: bookmarkBase64) else {
            throw NSError(domain: "LibraryTrack", code: 1, userInfo: [NSLocalizedDescriptionKey: "Не удалось декодировать bookmarkBase64"])
        }

        var isStale = false
        let resolved = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)

        if isStale {
            print("⚠️ BookmarkData устарела для: \(resolved.lastPathComponent)")
        }

        return resolved
    }
}

extension LibraryTrack {
    func startAccessingIfNeeded() -> URL? {
        do {
            let resolved = try resolveURL()
            let success = resolved.startAccessingSecurityScopedResource()
            if !success {
                print("❌ Не удалось начать доступ к \(resolved.lastPathComponent)")
                return nil
            }
            return resolved
        } catch {
            print("❌ Ошибка при восстановлении URL: \(error.localizedDescription)")
            return nil
        }
    }

    func stopAccessingIfNeeded() {
        do {
            let resolved = try resolveURL()
            resolved.stopAccessingSecurityScopedResource()
        } catch {
            print("❌ Ошибка при завершении доступа: \(error.localizedDescription)")
        }
    }
}


extension LibraryTrack {
    var displayTitle: String? {
        title ?? fileName
    }

    var displayArtist: String? {
        artist
    }
}


extension LibraryTrack: Equatable {
    static func == (lhs: LibraryTrack, rhs: LibraryTrack) -> Bool {
        lhs.id == rhs.id
    }
}
