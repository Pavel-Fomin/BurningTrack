//
//  BookmarksRegistry.swift
//  TrackList
//
//  Хранилище bookmark'ов для папок и локальных треков приложения.
//  Все рабочие bookmark'и сохраняются в SQLite.
//
//  Created by Pavel Fomin on 30.11.2025.
//

import Foundation

actor BookmarksRegistry {

    static let shared = BookmarksRegistry()

    // MARK: - Хранилище

    private var pendingPersistenceError: Error?
    private var cachedLibraryStore: LibraryDatabaseStore?
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    // MARK: - Загрузка

    func load() {
        print("🔑 BookmarksRegistry загружен из SQLite")
    }

    // MARK: - Ошибки записи

    func throwPendingPersistenceError() throws {
        if let pendingPersistenceError {
            self.pendingPersistenceError = nil
            throw pendingPersistenceError
        }
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
        do {
            try libraryStore().upsertTrackBookmark(
                id: id,
                bookmarkBase64: base64
            )
        } catch {
            rememberPersistenceError(error)
        }
    }

    func removeTrackBookmark(id: UUID) async {
        do {
            try libraryStore().removeTrackBookmark(id: id)
        } catch {
            rememberPersistenceError(error)
        }
    }

    func trackBookmark(for id: UUID) async -> String? {
        do {
            return try libraryStore().trackBookmark(id: id)
        } catch {
            rememberPersistenceError(error)
            return nil
        }
    }

    // MARK: - Private

    private func libraryStore() throws -> LibraryDatabaseStore {
        if let cachedLibraryStore {
            return cachedLibraryStore
        }

        let store = try LibraryDatabaseStore(database: database)
        cachedLibraryStore = store
        return store
    }

    private func rememberPersistenceError(_ error: Error) {
        pendingPersistenceError = error
        PersistentLogger.log("❌ BookmarksRegistry SQLite error: \(error)")
    }
}
