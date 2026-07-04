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

    /// identityKey -> trackId для внефазовых одиночных импортов.
    private var importedIdentityMap: [String: UUID] = [:]
    /// Старые library-ключи сохраняются в JSON как backup, но больше не используются как источник фонотеки.
    private var backupLibraryIdentityMap: [String: UUID] = [:]

    private var isLoaded = false
    private var isDirty = false

    // MARK: - Путь к файлу хранения

    private let fileURL: URL = {
        let dir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        return dir.appendingPathComponent("TrackIdentityRegistry.json")
    }()

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
        loadIfNeeded()

        let key = importedFileKey(for: url)
        return try await upsertImportedIdentityKey(key, preferredExistingId: nil)
    }

    /// Library identity хранится в SQLite, поэтому отдельная JSON-привязка больше не нужна.
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
        loadIfNeeded()

        let key = importedFileKey(for: url)

        if importedIdentityMap[key] == trackId { return }
        importedIdentityMap[key] = trackId
        isDirty = true
        try await persist()
    }

    /// Library identity удаляется вместе со строкой tracks, поэтому JSON-ключ не трогаем.
    func unbindLibraryTrack(
        rootFolderId: UUID,
        relativePath: String
    ) async throws {
        _ = rootFolderId
        _ = relativePath
    }

    /// Полностью забывает импортированные ключи, которые были привязаны к trackId.
    func forgetTrack(id trackId: UUID) async throws {
        loadIfNeeded()

        let oldCount = importedIdentityMap.count
        importedIdentityMap = importedIdentityMap.filter { $0.value != trackId }

        if importedIdentityMap.count != oldCount {
            isDirty = true
            try await persist()
        }
    }

    // MARK: - Внутренняя логика

    private func upsertImportedIdentityKey(
        _ key: String,
        preferredExistingId: UUID?
    ) async throws -> UUID {
        if let preferredExistingId {
            if importedIdentityMap[key] != preferredExistingId {
                importedIdentityMap[key] = preferredExistingId
                isDirty = true
                try await persist()
            }
            return preferredExistingId
        }

        if let existing = importedIdentityMap[key] {
            return existing
        }

        let newId = UUID()
        importedIdentityMap[key] = newId
        isDirty = true
        try await persist()
        return newId
    }

    // MARK: - Ключи identity

    private func importedFileKey(for url: URL) -> String {
        let normalizedPath = url
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path

        return "imp:\(normalizedPath)"
    }

    // MARK: - Загрузка / сохранение

    private func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([String: UUID].self, from: data)
            importedIdentityMap = decoded.filter { $0.key.hasPrefix("imp:") }
            backupLibraryIdentityMap = decoded.filter { $0.key.hasPrefix("imp:") == false }
        } catch {
            importedIdentityMap = [:]
            backupLibraryIdentityMap = [:]
        }
    }

    private func persist() async throws {
        guard isDirty else { return }

        // Сохраняем только legacy imports как активные ключи и оставляем старые library-ключи как backup.
        let file = backupLibraryIdentityMap.merging(importedIdentityMap) { _, imported in imported }
        let data = try JSONEncoder().encode(file)
        try data.write(to: fileURL, options: .atomic)
        isDirty = false
    }
}
