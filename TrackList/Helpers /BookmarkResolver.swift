//
//  BookmarkResolver.swift
//  TrackList
//
//  Единая точка доступа к файлам и папкам через bookmark'и.
//
//  Отвечает за:
//  - резолв bookmarkData → URL
//  - startAccessingSecurityScopedResource()
//  - stopAccessingSecurityScopedResource()
//  - хранение активных доступов (чтобы избежать sandbox ошибок)
//  - обработку устаревших bookmark'ов (stale)
//
//  TrackRegistry хранит только метаданные.
//  BookmarksRegistry хранит сами bookmarkData.
//  Все остальные менеджеры получают доступ к файлам ТОЛЬКО через этот слой.
//
//  Created by Pavel Fomin on 01.12.2025.
//

import Foundation

enum BookmarkResolver {

    // MARK: - Хранилище активных доступов
    
    private static var activeAccesses = Set<URL>()
    private static let accessQueue = DispatchQueue(label: "BookmarkResolver.accessQueue")

    // MARK: - Публичный метод: получить URL трека

    /// Возвращает доступный URL трека, автоматически резолвя bookmark и открывая доступ.
    static func url(forTrack id: UUID) async -> URL? {
        guard let base64 = await BookmarksRegistry.shared.trackBookmark(for: id),
              let url = resolveBookmark(base64) else {
            return nil
        }

        startAccessingIfNeeded(url)
        return url
    }


    // MARK: - Публичный метод: получить URL папки (root)

    /// Возвращает доступный URL папки.
    static func url(forFolder id: UUID) async -> URL? {
        guard let base64 = await BookmarksRegistry.shared.folderBookmark(for: id),
              let url = resolveBookmark(base64) else {
            return nil
        }

        startAccessingIfNeeded(url)
        return url
    }


    // MARK: - Приватный: резолв bookmarkData → URL

    /// Резолвит bookmarkData (base64) → URL.
    /// Если bookmark устарел — печатаем предупреждение.
    private static func resolveBookmark(_ base64: String) -> URL? {
        guard let data = Data(base64Encoded: base64) else { return nil }

        var stale = false
        let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )

        if stale {
            print("⚠️ BookmarkResolver: bookmark устарел для URL:", url?.path ?? "nil")
        }

        return url
    }


    // MARK: - Приватный: старт доступа

    /// Вызывает startAccessingSecurityScopedResource() только если доступ ещё не открыт.
    private static func startAccessingIfNeeded(_ url: URL) {
        accessQueue.sync {
            if activeAccesses.contains(url) {
                return
            }

            if url.startAccessingSecurityScopedResource() {
                activeAccesses.insert(url)
            } else {
                print("❌ BookmarkResolver: не удалось начать доступ —", url.path)
            }
        }
    }


    // MARK: - Публичный: остановить доступ

    /// Явное завершение доступа (редко используется, но полезно для импорта/экспорта).
    static func stopAccessing(_ url: URL) {
        accessQueue.sync {
            guard activeAccesses.contains(url) else { return }

            url.stopAccessingSecurityScopedResource()
            activeAccesses.remove(url)
        }
    }


    // MARK: - Хелпер: создание bookmarkData для папки или файла

    /// Создаёт bookmarkData и возвращает base64-строку.
    /// Используется при добавлении папки и индексации треков.
    static func makeBookmarkBase64(for url: URL) -> String? {
        do {
            let data = try url.bookmarkData()
            return data.base64EncodedString()
        } catch {
            print("❌ BookmarkResolver: не удалось создать bookmark:", error)
            return nil
        }
    }
}
