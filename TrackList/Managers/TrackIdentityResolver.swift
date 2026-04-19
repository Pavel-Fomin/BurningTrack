//
//  TrackIdentityResolver.swift
//  TrackList
//
//  Слой идентичности треков.
//
//  ВАЖНО:
//  - trackId создаётся только здесь
//  - trackId больше не зависит от тегов, размера файла и байтов содержимого
//  - для фонотеки identity строится из rootFolderId + relativePath
//  - для одиночных импортов identity строится из нормализованного пути файла
//
//  Created by Pavel Fomin on 30.12.2025.
//

import Foundation

actor TrackIdentityResolver {

    static let shared = TrackIdentityResolver()

    // MARK: - Хранилище соответствий

    /// identityKey -> trackId
    private var identityMap: [String: UUID] = [:]

    private var isLoaded = false

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
    /// Если в реестре уже есть существующий id для этого logical path,
    /// он будет сохранён и переиспользован.
    func trackId(
        forRootFolderId rootFolderId: UUID,
        relativePath: String,
        preferredExistingId: UUID? = nil
    ) async -> UUID {
        await loadIfNeeded()

        let key = libraryKey(
            rootFolderId: rootFolderId,
            relativePath: relativePath
        )

        return await upsertIdentityKey(
            key,
            preferredExistingId: preferredExistingId
        )
    }

    /// Возвращает постоянный trackId для одиночного импортированного файла.
    /// Используется только там, где нет library root и relativePath.
    func trackId(forImportedURL url: URL) async -> UUID {
        await loadIfNeeded()

        let key = importedFileKey(for: url)
        return await upsertIdentityKey(key, preferredExistingId: nil)
    }

    /// Привязывает уже известный trackId к библиотечному ключу.
    /// Нужен после rename / move и при sync, когда id уже известен из реестра.
    func bindLibraryTrack(
        id trackId: UUID,
        rootFolderId: UUID,
        relativePath: String
    ) async {
        await loadIfNeeded()

        let key = libraryKey(
            rootFolderId: rootFolderId,
            relativePath: relativePath
        )

        if identityMap[key] == trackId { return }
        identityMap[key] = trackId
        await persist()
    }

    /// Привязывает уже известный trackId к импортированному файлу.
    func bindImportedTrack(
        id trackId: UUID,
        url: URL
    ) async {
        await loadIfNeeded()

        let key = importedFileKey(for: url)

        if identityMap[key] == trackId { return }
        identityMap[key] = trackId
        await persist()
    }

    /// Удаляет только библиотечный ключ.
    /// Сам trackId при этом не трогаем.
    func unbindLibraryTrack(
        rootFolderId: UUID,
        relativePath: String
    ) async {
        await loadIfNeeded()

        let key = libraryKey(
            rootFolderId: rootFolderId,
            relativePath: relativePath
        )

        if identityMap.removeValue(forKey: key) != nil {
            await persist()
        }
    }

    /// Полностью забывает все ключи, которые были привязаны к trackId.
    /// Используется только когда трек реально исчез из библиотеки.
    func forgetTrack(id trackId: UUID) async {
        await loadIfNeeded()

        let oldCount = identityMap.count
        identityMap = identityMap.filter { $0.value != trackId }

        if identityMap.count != oldCount {
            await persist()
        }
    }

    // MARK: - Внутренняя логика

    private func upsertIdentityKey(
        _ key: String,
        preferredExistingId: UUID?
    ) async -> UUID {
        if let preferredExistingId {
            if identityMap[key] != preferredExistingId {
                identityMap[key] = preferredExistingId
                await persist()
            }
            return preferredExistingId
        }

        if let existing = identityMap[key] {
            return existing
        }

        let newId = UUID()
        identityMap[key] = newId
        await persist()
        return newId
    }

    // MARK: - Ключи identity

    private func libraryKey(
        rootFolderId: UUID,
        relativePath: String
    ) -> String {
        let normalizedPath = normalizeRelativePath(relativePath)
        return "lib:\(rootFolderId.uuidString):\(normalizedPath)"
    }

    private func importedFileKey(for url: URL) -> String {
        let normalizedPath = url
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path

        return "imp:\(normalizedPath)"
    }

    private func normalizeRelativePath(_ relativePath: String) -> String {
        relativePath
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    // MARK: - Загрузка / сохранение

    private func loadIfNeeded() async {
        guard !isLoaded else { return }
        isLoaded = true

        do {
            let data = try Data(contentsOf: fileURL)
            identityMap = try JSONDecoder().decode([String: UUID].self, from: data)
        } catch {
            identityMap = [:]
        }
    }

    private func persist() async {
        do {
            let data = try JSONEncoder().encode(identityMap)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("❌ Ошибка сохранения TrackIdentityRegistry:", error)
        }
    }
}
