//
//  TrackRegistry.swift
//  TrackList
//
//  Централизованный реестр треков — человекочитаемая структура JSON.
//
//  Created by Pavel Fomin on 10.11.2025.
//

import Foundation

actor TrackRegistry {

    // MARK: - Вложенные типы

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
    
    struct FolderEntry: Codable, Identifiable {
        var id: UUID
        var name: String
        var path: String
        var updatedAt: Date
    }

    // MARK: - Свойства

    static let shared = TrackRegistry()
    private var registry: [UUID: TrackEntry] = [:]
    private var folders: [UUID: FolderEntry] = [:]

    private let fileURL: URL = {
        // Берём основную папку приложения, без добавления "Track List"
        let appDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Создаём файл прямо в корне
        let file = appDir.appendingPathComponent("TrackRegistry.json")
        return file
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
            folders = Dictionary(uniqueKeysWithValues: decoded.folders.map { ($0.id, $0) })
            registry = Dictionary(uniqueKeysWithValues: decoded.registry.map { ($0.id, $0) })
            print("📘 TrackRegistry загружен (\(registry.count) записей)")
        } catch {
            print("ℹ️ TrackRegistry: нет файла или ошибка загрузки — создан новый.")
            registry = [:]
        }
    }
    
    
// MARK: - Загрузка / сохранение (Структура json)

    func persist() {
        let sorted = registry.values.sorted { $0.updatedAt > $1.updatedAt }
        let sortedFolders = folders.values.sorted { $0.updatedAt > $1.updatedAt }
        let fileData = RegistryFile(folders: sortedFolders, registry: sorted)                        /// Создаём объект, который станет JSON
        do {
            let data = try encoder.encode(fileData)                          /// JSONEncoder превращает RegistryFile в JSON
            try data.write(to: fileURL, options: .atomic)
            print("💾 TrackRegistry сохранён (\(registry.count) записей)")
        } catch {
            print("❌ Ошибка сохранения TrackRegistry: \(error)")
        }
    }

    
    // MARK: - Удаление всех треков по папке
    
    func removeTracks(inFolder folderId: UUID) {
        let beforeCount = registry.count
        let removedTracks = registry.values.filter { $0.folderId == folderId }
        registry = registry.filter { $0.value.folderId != folderId }
        persist()
        
        let diff = beforeCount - registry.count
        if diff > 0 {
            print("🧹 TrackRegistry: удалено \(diff) треков из папки \(folderId.uuidString.prefix(8))")
        } else {
            print("ℹ️ TrackRegistry: нет треков для удаления (\(folderId.uuidString.prefix(8)))")
        }
    }
    
    
    // MARK: - API

    func register(trackId: UUID, bookmarkBase64: String, folderId: UUID, fileName: String) {
        if let existing = registry[trackId] {
            // 🔹 Проверяем: если уже есть, и bookmark + folder совпадают, выходим
            if existing.bookmarkBase64 == bookmarkBase64 && existing.folderId == folderId {
                return // уже зарегистрирован, не трогаем
            }
            // 🔸 Если изменился bookmark или folder — обновляем
            var updated = existing
            updated.bookmarkBase64 = bookmarkBase64
            updated.folderId = folderId
            updated.updatedAt = Date()
            registry[trackId] = updated
            persist()
            print("🔁 Обновлён трек: \(fileName)")
            return
        }

        // 🆕 Новый трек — добавляем в реестр
        let entry = TrackEntry(
            id: trackId,
            fileName: fileName,
            folderId: folderId,
            bookmarkBase64: bookmarkBase64,
            updatedAt: Date()
        )
        registry[trackId] = entry
        persist()
        print("✅ Зарегистрирован новый трек: \(fileName)")
    }
    
    // Регистрации папок
    func registerFolder(folderId: UUID, name: String, path: String) {
        let entry = FolderEntry(
            id: folderId,
            name: name,
            path: path,
            updatedAt: Date()
        )
        folders[folderId] = entry
        persist()
        print("📁 Зарегистрирована папка: \(name)")
    }

    func resolvedURL(for id: UUID) -> URL? {
        guard let entry = registry[id],
              let data = Data(base64Encoded: entry.bookmarkBase64)
        else { return nil }

        var stale = false
        do {
            let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale)
            if stale { print("⚠️ Bookmark устарел для трека \(entry.fileName)") }
            return url
        } catch {
            print("❌ Ошибка резолва URL: \(error)")
            return nil
        }
    }

    func updateBookmark(for id: UUID, newBookmark: String) {
        guard var entry = registry[id] else { return }
        entry.bookmarkBase64 = newBookmark
        entry.updatedAt = Date()
        registry[id] = entry
        persist()
        print("🔁 Обновлён bookmark для трека \(entry.fileName)")
    }

    func remove(trackId: UUID) {
        guard let entry = registry.removeValue(forKey: trackId) else { return }
        persist()
        print("🗑️ Удалён трек из реестра: \(entry.fileName)")
    }

    func allEntries() -> [TrackEntry] {
        registry.values.sorted { $0.updatedAt > $1.updatedAt }
    }
}
