//
//  BookmarkResolver.swift
//  TrackList
//
//  Централизованный слой доступа к файлам и папкам через bookmark'и.
//
//  Работает ТОЛЬКО со вторичным доступом (после первичного прикрепления).
//  Первичный доступ всегда открывает MusicLibraryManager.saveBookmark().
//
//  Created by Pavel Fomin on 01.12.2025.
//

import Foundation

enum BookmarkResolver {

    // MARK: - Активные security-доступы (чтобы не дублировать startAccessing)

    private static var activeAccesses = Set<URL>()
    private static let accessQueue = DispatchQueue(label: "BookmarkResolver.accessQueue")

    // MARK: - URL для трека

    static func url(forTrack id: UUID) async -> URL? {
        guard let base64 = await BookmarksRegistry.shared.trackBookmark(for: id) else {
            print("⚠️ BookmarkResolver: нет bookmark для трека \(id)")
            return nil
        }

        guard let url = resolveBookmark(base64) else {
            print("⚠️ BookmarkResolver: не удалось резолвить bookmark трека \(id)")
            return nil
        }

        startAccessingIfNeeded(url)
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

        startAccessingIfNeeded(url)
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
                options: [.withoutUI], // .withSecurityScope больше нет в iOS 26
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
        } catch {
            print("❌ BookmarkResolver: ошибка резолва bookmark:", error)
            return nil
        }

        if stale {
            print("⚠️ BookmarkResolver: bookmark устарел →", url.path)
        }

        return url
    }

    // MARK: - Старт доступа (централизованный)

    private static func startAccessingIfNeeded(_ url: URL) {
        accessQueue.sync {
            if activeAccesses.contains(url) { return }

            if url.startAccessingSecurityScopedResource() {
                activeAccesses.insert(url)
            } else {
                print("""
                ❌ BookmarkResolver: startAccessingSecurityScopedResource() вернул false
                URL: \(url.path)
                Возможные причины:
                - bookmark создан без security-scope (до фикса)
                - файл перемещён / удалён
                - у приложения нет доступа
                """)
            }
        }
    }

    // MARK: - Явное завершение доступа

    static func stopAccessing(_ url: URL) {
        accessQueue.sync {
            guard activeAccesses.contains(url) else { return }

            url.stopAccessingSecurityScopedResource()
            activeAccesses.remove(url)
        }
    }

    // MARK: - Создание bookmarkData (только для bootstrap и индексации файлов)

    static func makeBookmarkBase64(for url: URL) -> String? {
        // Даже если MusicLibraryManager открыл доступ,
        // для файлов доступ может не быть открыт → открываем локально.
        let started = url.startAccessingSecurityScopedResource()
        defer { if started { url.stopAccessingSecurityScopedResource() } }

        do {
            // На iOS 26 bookmark с security-scope создаётся автоматически
            // если доступ был открыт.
            let data = try url.bookmarkData(options: [.minimalBookmark])
            return data.base64EncodedString()
        } catch {
            print("❌ BookmarkResolver: не удалось создать bookmark:", error)
            return nil
        }
    }
}
