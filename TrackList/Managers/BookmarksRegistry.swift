//
//  BookmarksRegistry.swift
//  TrackList
//
//  Хранилище bookmark'ов для папок и треков.
//  Для фонотеки использует SQLite, для внефазовых одиночных импортов сохраняет legacy JSON.
//
//  Created by Pavel Fomin on 30.11.2025.
//

import Foundation

actor BookmarksRegistry {

    static let shared = BookmarksRegistry()

    // MARK: - Вложенные типы

    struct FolderBookmark: Codable, Identifiable {
        var id: UUID           // folderId
        var base64: String
        var updatedAt: Date
    }

    struct TrackBookmark: Codable, Identifiable {
        var id: UUID           // trackId
        var base64: String
        var updatedAt: Date
    }

    struct BookmarkFile: Codable {
        var folders: [FolderBookmark]
        var tracks: [TrackBookmark]
    }

    // MARK: - Хранилище

    private var backupFolderBookmarks: [FolderBookmark] = []
    private var legacyTrackBookmarks: [UUID: TrackBookmark] = [:]
    private var isLegacyLoaded = false
    private var legacyDirty = false
    private var pendingPersistenceError: Error?
    private var cachedLibraryStore: LibraryDatabaseStore?

    private let fileURL: URL = {
        let appDir = FileManager.default.urls(for: .documentDirectory,
                                              in: .userDomainMask).first!
        return appDir.appendingPathComponent("BookmarksRegistry.json")
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Загрузка

    func load() {
        // JSON больше не является источником bookmark'ов фонотеки.
        isLegacyLoaded = false
        loadLegacyIfNeeded()

        print("🔑 BookmarksRegistry загружен из SQLite (legacy bookmarks: \(legacyTrackBookmarks.count))")
    }

    // MARK: - Сохранение

    func persist() throws {
        if let pendingPersistenceError {
            self.pendingPersistenceError = nil
            throw pendingPersistenceError
        }

        guard legacyDirty else {
            print(" BookmarksRegistry: SQLite-изменения уже сохранены")
            return
        }

        let file = BookmarkFile(
            folders: backupFolderBookmarks,
            tracks: legacyTrackBookmarks.values.sorted { $0.updatedAt > $1.updatedAt }
        )

        // Legacy JSON пишется только для внефазовых импортов и сохраняет старые backup-записи.
        let data = try encoder.encode(file)
        try data.write(to: fileURL, options: .atomic)
        legacyDirty = false
        print(" BookmarksRegistry legacy imports сохранён")
    }

    // MARK: - Папки

    func upsertFolderBookmark(id: UUID, base64: String) {
        do {
            try libraryStore().upsertRootFolderBookmark(
                id: id,
                bookmarkBase64: base64
            )
        } catch {
            rememberPersistenceError(error)
        }
    }

    func removeFolderBookmark(id: UUID) {
        do {
            try libraryStore().removeFolderBookmark(id: id)
        } catch {
            rememberPersistenceError(error)
        }
    }

    func folderBookmark(for id: UUID) -> String? {
        do {
            return try libraryStore().folderBookmark(id: id)
        } catch {
            rememberPersistenceError(error)
            return nil
        }
    }

    // MARK: - Треки

    func upsertTrackBookmark(id: UUID, base64: String) async {
        if await TrackRegistry.shared.isLibraryTrack(id: id) {
            do {
                try libraryStore().upsertTrackBookmark(
                    id: id,
                    bookmarkBase64: base64
                )
            } catch {
                rememberPersistenceError(error)
            }
            return
        }

        loadLegacyIfNeeded()
        legacyTrackBookmarks[id] = TrackBookmark(
            id: id,
            base64: base64,
            updatedAt: Date()
        )
        legacyDirty = true
    }

    func removeTrackBookmark(id: UUID) async {
        do {
            try libraryStore().removeTrackBookmark(id: id)
        } catch {
            rememberPersistenceError(error)
        }

        loadLegacyIfNeeded()
        guard await TrackRegistry.shared.isLegacyImportedTrack(id: id) else { return }

        if legacyTrackBookmarks.removeValue(forKey: id) != nil {
            legacyDirty = true
        }
    }

    func trackBookmark(for id: UUID) async -> String? {
        do {
            if let bookmark = try libraryStore().trackBookmark(id: id) {
                return bookmark
            }
        } catch {
            rememberPersistenceError(error)
        }

        guard await TrackRegistry.shared.isLegacyImportedTrack(id: id) else {
            return nil
        }

        loadLegacyIfNeeded()
        return legacyTrackBookmarks[id]?.base64
    }

    // MARK: - Private

    private func libraryStore() throws -> LibraryDatabaseStore {
        if let cachedLibraryStore {
            return cachedLibraryStore
        }

        let store = try LibraryDatabaseStore()
        cachedLibraryStore = store
        return store
    }

    private func loadLegacyIfNeeded() {
        guard isLegacyLoaded == false else { return }
        isLegacyLoaded = true

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try decoder.decode(BookmarkFile.self, from: data)

            backupFolderBookmarks = decoded.folders
            legacyTrackBookmarks = Dictionary(
                uniqueKeysWithValues: decoded.tracks.map { ($0.id, $0) }
            )
        } catch {
            backupFolderBookmarks = []
            legacyTrackBookmarks = [:]
        }
    }

    private func rememberPersistenceError(_ error: Error) {
        pendingPersistenceError = error
        PersistentLogger.log("❌ BookmarksRegistry SQLite error: \(error)")
    }
}
