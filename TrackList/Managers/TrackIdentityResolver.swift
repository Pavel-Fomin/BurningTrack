//
//  TrackIdentityResolver.swift
//  TrackList
//
//  Слой идентичности треков.
//
//  ВАЖНО:
//  - trackId создаётся только здесь
//  - trackId больше не зависит от тегов, размера файла и байтов содержимого
//  - для фонотеки identity строится из SQLite-записи tracks(root_folder_id, relative_path)
//  - для одиночных импортов identity строится из нормализованного пути файла
//
//  Created by Pavel Fomin on 30.12.2025.
//

import Foundation

actor TrackIdentityResolver {

    static let shared = TrackIdentityResolver()

    // MARK: - Хранилище соответствий

    private var cachedIdentityStore: TrackIdentityDatabaseStore?
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    // MARK: - Публичный API

    /// Возвращает постоянный trackId для трека фонотеки.
    /// SQLite tracks(root_folder_id, relative_path) теперь является источником library identity.
    func trackId(
        forRootFolderId rootFolderId: UUID,
        relativePath: String,
        preferredExistingId: UUID? = nil
    ) async throws -> UUID {
        if let existing = await TrackRegistry.shared.entry(
            inRootFolder: rootFolderId,
            relativePath: relativePath
        ) {
            return existing.id
        }

        if let preferredExistingId {
            return preferredExistingId
        }

        return UUID()
    }

    /// Возвращает постоянный trackId для одиночного импортированного файла.
    /// Используется только там, где нет rootFolderId + relativePath.
    func trackId(forImportedURL url: URL) async throws -> UUID {
        let key = importedFileKey(for: url)
        return try identityStore().trackIdForImportedIdentity(
            identityKey: key,
            fileURL: url
        )
    }

    /// Library identity хранится в tracks(root_folder_id, relative_path), поэтому отдельная привязка не нужна.
    func bindLibraryTrack(
        id trackId: UUID,
        rootFolderId: UUID,
        relativePath: String
    ) async throws {
        _ = trackId
        _ = rootFolderId
        _ = relativePath
    }

    /// Привязывает уже известный trackId к импортированному файлу.
    func bindImportedTrack(
        id trackId: UUID,
        url: URL
    ) async throws {
        let key = importedFileKey(for: url)
        try identityStore().bindImportedTrack(
            id: trackId,
            identityKey: key,
            fileURL: url
        )
    }

    /// Заменяет path-identity imported-трека после физического rename/move.
    func replaceImportedTrackIdentity(
        id trackId: UUID,
        url: URL
    ) async throws {
        let key = importedFileKey(for: url)
        try identityStore().replaceImportedTrackIdentity(
            id: trackId,
            identityKey: key,
            fileURL: url
        )
    }

    /// Library identity удаляется вместе со строкой tracks.
    func unbindLibraryTrack(
        rootFolderId: UUID,
        relativePath: String
    ) async throws {
        _ = rootFolderId
        _ = relativePath
    }

    /// Полностью забывает импортированные ключи, которые были привязаны к trackId.
    func forgetTrack(id trackId: UUID) async throws {
        try identityStore().forgetTrack(id: trackId)
    }

    // MARK: - Внутренняя логика

    private func identityStore() throws -> TrackIdentityDatabaseStore {
        if let cachedIdentityStore {
            return cachedIdentityStore
        }

        let store = try TrackIdentityDatabaseStore(database: database)
        cachedIdentityStore = store
        return store
    }

    // MARK: - Ключи identity

    private func importedFileKey(for url: URL) -> String {
        let normalizedPath = url
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path

        return "imp:\(normalizedPath)"
    }
}
