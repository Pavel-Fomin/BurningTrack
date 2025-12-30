//
//  LibrarySyncModule.swift
//  TrackList
//
//  Sync-модуль фонотеки.
//  Единственная ответственность:
//  — привести реестры (TrackRegistry + BookmarksRegistry) в соответствие фактическому
//    состоянию файловой системы фонотеки.
//
//  Жёсткие границы:
//  — не знает про UI
//  — не читает метаданные аудио (теги/обложки/длительность)
//  — trackId создаётся только через TrackIdentityResolver
//  — источник фактов о ФС: LibraryScanner
//
//  Created by Pavel Fomin on 30.12.2025.
//

import Foundation

actor LibrarySyncModule {

    static let shared = LibrarySyncModule()

    private let scanner = LibraryScanner()

    private init() {}

    // MARK: - Публичный API

    /// Синхронизирует один корневой раздел фонотеки:
    /// - сканирует все аудиофайлы внутри rootURL
    /// - для каждого файла получает постоянный trackId через TrackIdentityResolver
    /// - обновляет TrackRegistry/BookmarksRegistry
    /// - удаляет из реестров треки, которых больше нет в файловой системе
    ///
    /// Важно: URL может меняться, идентичность файла — нет.
    /// 
    func syncRootFolder(rootFolderId: UUID, rootURL: URL) async {

        // 1) Открываем доступ к корневой папке на время синка
        let started = rootURL.startAccessingSecurityScopedResource()
        if !started {
            print("❌ syncRootFolder: не удалось начать доступ к папке:", rootURL.path)
            return
        }
        defer { rootURL.stopAccessingSecurityScopedResource() }

        // 2) Сканируем все аудиофайлы рекурсивно
        let scanned = await scanner.scanRecursively(rootURL)

        // 3) Получаем текущее состояние реестра по корню
        let existing = await TrackRegistry.shared.tracks(inRootFolder: rootFolderId)
        var existingById: [UUID: TrackRegistry.TrackEntry] = [:]
        for entry in existing { existingById[entry.id] = entry }

        // 4) Применяем найденные файлы: upsert + bookmark
        var aliveIds = Set<UUID>()

        for file in scanned {

            let fileURL = file.url
            let fileName = file.fileName
            let folderId = file.folderURL.libraryFolderId

            // Постоянный id физического файла
            let trackId = await TrackIdentityResolver.shared.trackId(for: fileURL)
            aliveIds.insert(trackId)

            await TrackRegistry.shared.upsertTrack(
                id: trackId,
                fileName: fileName,
                folderId: folderId,
                rootFolderId: rootFolderId
            )

            // Bookmark файла (может обновляться, это не идентичность)
            if let base64 = BookmarkResolver.makeBookmarkBase64(for: fileURL) {
                await BookmarksRegistry.shared.upsertTrackBookmark(id: trackId, base64: base64)
            } else {
                print("⚠️ syncRootFolder: не удалось создать bookmark файла:", fileURL.path)
            }
        }

        // 5) Удаляем из реестров треки, которых больше нет в файловой системе
        for entry in existing {
            if aliveIds.contains(entry.id) { continue }
            await TrackRegistry.shared.removeTrack(id: entry.id)
            await BookmarksRegistry.shared.removeTrackBookmark(id: entry.id)
        }

        // 6) Persist — один раз
        await TrackRegistry.shared.persist()
        await BookmarksRegistry.shared.persist()

        print("✅ syncRootFolder завершён:", rootURL.lastPathComponent, "файлов:", scanned.count, "удалено:", existing.count - aliveIds.count)
    }
}
