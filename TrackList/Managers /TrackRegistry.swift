//
//  TrackRegistry.swift
//  TrackList
//
//  Централизованный реестр треков и папок.
//
//  Хранит:
//  - список папок (FolderEntry)
//  - список треков (TrackEntry)
//  - быстрый индекс: absolutePath → trackId
//
//  Created by Pavel Fomin on 10.11.2025.
//

import Foundation

actor TrackRegistry {

    // MARK: - Вложенные типы

    struct FolderEntry: Codable, Identifiable {
        var id: UUID
        var name: String
        var path: String
        var bookmarkBase64: String
        var updatedAt: Date
    }

    struct TrackEntry: Codable, Identifiable {
        var id: UUID
        var fileName: String
        var folderId: UUID
        var bookmarkBase64: String
        var updatedAt: Date
    }

    struct RegistryFile: Codable {
        var folders: [FolderEntry]
        var registry: [TrackEntry]
    }


    // MARK: - Свойства

    static let shared = TrackRegistry()

    private var registry: [UUID: TrackEntry] = [:]
    private var folders: [UUID: FolderEntry] = [:]

    /// Быстрый индекс: абсолютный путь → trackId
    private var pathIndex: [String: UUID] = [:]

    private let fileURL: URL = {
        let appDir = FileManager.default.urls(for: .documentDirectory,
                                              in: .userDomainMask).first!
        return appDir.appendingPathComponent("TrackRegistry.json")
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


    // MARK: - Загрузка / сохранение

    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try decoder.decode(RegistryFile.self, from: data)

            folders = Dictionary(uniqueKeysWithValues:
                                    decoded.folders.map { ($0.id, $0) })

            registry = Dictionary(uniqueKeysWithValues:
                                    decoded.registry.map { ($0.id, $0) })

            // Перестраиваем быстрый индекс
            rebuildPathIndex(from: decoded.registry)

            print("📘 TrackRegistry загружен (\(registry.count) треков)")
        } catch {
            print("ℹ️ TrackRegistry: нет файла, создаём новый.")
            folders = [:]
            registry = [:]
            pathIndex = [:]
        }
    }

    private func rebuildPathIndex(from entries: [TrackEntry]) {
        pathIndex = [:]

        for entry in entries {
            if let data = Data(base64Encoded: entry.bookmarkBase64) {
                var stale = false
                if let url = try? URL(
                    resolvingBookmarkData: data,
                    bookmarkDataIsStale: &stale
                ) {
                    pathIndex[url.path] = entry.id
                }
            }
        }
    }


    func persist() {
        let file = RegistryFile(
            folders: folders.values.sorted { $0.updatedAt > $1.updatedAt },
            registry: registry.values.sorted { $0.updatedAt > $1.updatedAt }
        )

        do {
            let data = try encoder.encode(file)
            try data.write(to: fileURL, options: .atomic)
            print("💾 TrackRegistry сохранён")
        } catch {
            print("❌ Ошибка сохранения TrackRegistry: \(error)")
        }
    }


    // MARK: - API — Работа с папками

    func registerFolder(
        folderId: UUID,
        name: String,
        path: String,
        bookmarkBase64: String
    ) {
        let entry = FolderEntry(
            id: folderId,
            name: name,
            path: path,
            bookmarkBase64: bookmarkBase64,
            updatedAt: Date()
        )
        folders[folderId] = entry
        persist()
    }

    func foldersList() -> [FolderEntry] {
        folders.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    func removeFolder(folderId: UUID) {
        folders.removeValue(forKey: folderId)
        removeTracks(inFolder: folderId)
        persist()
        print("🗑️ Удалена папка \(folderId)")
    }
    
    
    // MARK: - API — Работа с треками

    func register(
        trackId: UUID,
        bookmarkBase64: String,
        folderId: UUID,
        fileName: String
    ) {
        // Удаляем старый путь из индекса, если был
        if let existing = registry[trackId],
           let oldData = Data(base64Encoded: existing.bookmarkBase64)
        {
            var stale = false
            if let oldURL = try? URL(
                resolvingBookmarkData: oldData,
                bookmarkDataIsStale: &stale
            ) {
                pathIndex.removeValue(forKey: oldURL.path)
            }
        }

        // Резолвим новый bookmark → URL
        var newPath: String?
        if let data = Data(base64Encoded: bookmarkBase64) {
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                bookmarkDataIsStale: &stale
            ) {
                newPath = url.path
                pathIndex[url.path] = trackId
            }
        }

        // Сохраняем обновлённую запись
        let entry = TrackEntry(
            id: trackId,
            fileName: fileName,
            folderId: folderId,
            bookmarkBase64: bookmarkBase64,
            updatedAt: Date()
        )

        registry[trackId] = entry
        persist()

        print("🎧 Зарегистрирован трек: \(fileName)\(newPath != nil ? " → \(newPath!)" : "")")
    }


    func removeTracks(inFolder folderId: UUID) {
        let before = registry.count

        registry = registry.filter { $0.value.folderId != folderId }
        persist()

        let removed = before - registry.count
        print("🗑️ Удалено \(removed) треков для папки \(folderId)")
    }


    func remove(trackId: UUID) {
        registry.removeValue(forKey: trackId)
        persist()
    }


    // MARK: - URL Resolution

    func resolvedURL(for id: UUID) -> URL? {
        guard let entry = registry[id],
              let data = Data(base64Encoded: entry.bookmarkBase64) else {
            return nil
        }

        var stale = false
        return try? URL(
            resolvingBookmarkData: data,
            bookmarkDataIsStale: &stale
        )
    }

    nonisolated
    func resolvedURLSync(for id: UUID) -> URL? {
        var result: URL?
        let sema = DispatchSemaphore(value: 0)

        Task {
            result = await self.resolvedURL(for: id)
            sema.signal()
        }

        sema.wait()
        return result
    }


    // MARK: - Быстрый trackId по пути

    func trackId(for url: URL) async -> UUID {
        let path = url.path

        // 1) Мгновенный поиск
        if let id = pathIndex[path] {
            return id
        }

        // 2) Генерируем новый стабильный UUID(v5)
        let newId = UUID.v5(from: path)
        pathIndex[path] = newId
        return newId
    }
}

// MARK: - Convenience

extension TrackRegistry {
    /// Возвращает актуальный resolvedURL для исходного fileURL через TrackRegistry
    func resolve(url: URL) async -> URL {
        let id = await trackId(for: url)         // async — нормально
        return resolvedURL(for: id) ?? url       // синхронно — await не нужен
    }
}
