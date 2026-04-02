//
//  BookmarkResolver.swift
//  TrackList
//
//  Централизованный слой доступа к файлам и папкам через bookmark'и.
//
//  ВАЖНО:
//  - BookmarkResolver НЕ управляет startAccessing/stopAccessing.
//  - Root-доступ держит MusicLibraryManager (на весь runtime).
//  - Здесь только восстановление URL из реестров.
//
//  Created by Pavel Fomin on 01.12.2025.
//

import Foundation

enum BookmarkResolver {

    // MARK: - URL для трека

    // MARK: - URL для трека

    static func url(forTrack id: UUID) async -> URL? {

        // 1) Основной путь: rootFolder + relativePath (фонотека)
        if let entry = await TrackRegistry.shared.entry(for: id),
           entry.relativePath.isEmpty == false {

            guard let rootURL = await url(forFolder: entry.rootFolderId) else {
                print("⚠️ BookmarkResolver: не удалось восстановить rootURL для трека \(id)")
                return nil
            }

            // Собираем путь из root + relativePath
            let candidateURL = rootURL.appendingPathComponent(entry.relativePath)

            // Если файл реально существует — это валидный путь
            if FileManager.default.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }

            // Если файла по relativePath уже нет, не считаем это фатальной ошибкой.
            // Такое возможно сразу после move / rename:
            // bookmark уже обновлён, а relativePath ещё нет.
            print("⚠️ BookmarkResolver: stale relativePath для трека \(id), пробуем bookmark fallback")
        }

        // 2) Fallback: bookmark трека
        guard let base64 = await BookmarksRegistry.shared.trackBookmark(for: id) else {
            print("⚠️ BookmarkResolver: нет пути к треку \(id)")
            return nil
        }

        guard let url = resolveBookmark(base64) else {
            print("⚠️ BookmarkResolver: не удалось резолвить bookmark трека \(id)")
            return nil
        }

        return url
    }

    // MARK: - URL для папки

    static func url(forFolder id: UUID) async -> URL? {
        guard let base64 = await BookmarksRegistry.shared.folderBookmark(for: id) else {
            print("⚠️ BookmarkResolver: нет bookmark для папки \(id)")
            return nil
        }

        guard let url = resolveBookmark(base64) else {
            print("⚠️ BookmarkResolver: не удалось резолвить bookmark папки \(id)")
            return nil
        }

        return url
    }

    // MARK: - Резолв bookmark → URL

    private static func resolveBookmark(_ base64: String) -> URL? {
        guard let data = Data(base64Encoded: base64) else {
            print("❌ BookmarkResolver: не удалось декодировать base64")
            return nil
        }

        var stale = false

        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: data,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
        } catch {
            print("❌ BookmarkResolver: ошибка резолва bookmark:", error)
            PersistentLogger.log("❌ BookmarkResolver: resolveBookmark failed: \(error)")
            return nil
        }

        if stale {
            print("⚠️ BookmarkResolver: bookmark устарел →", url.path)
            PersistentLogger.log("⚠️ BookmarkResolver: bookmark stale url=\(url.path)")
        }

        return url
    }

    // MARK: - Создание bookmarkData (только для bootstrap и индексации)

    static func makeBookmarkBase64(for url: URL) -> String? {
        do {
            let data = try url.bookmarkData(options: [.minimalBookmark])
            return data.base64EncodedString()
        } catch {
            print("❌ BookmarkResolver: не удалось создать bookmark:", error)
            return nil
        }
    }
}
