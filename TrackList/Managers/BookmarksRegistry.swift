//
//  BookmarksRegistry.swift
//  TrackList
//
//  Хранилище bookmark'ов для папок и треков.
//  TrackRegistry хранит только метаданные.
//  BookmarksRegistry отвечает исключительно за доступ.
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

    private var folderBookmarks: [UUID: FolderBookmark] = [:]
    private var trackBookmarks:  [UUID: TrackBookmark]  = [:]

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
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try decoder.decode(BookmarkFile.self, from: data)

            folderBookmarks = Dictionary(uniqueKeysWithValues:
                decoded.folders.map { ($0.id, $0) })

            trackBookmarks = Dictionary(uniqueKeysWithValues:
                decoded.tracks.map { ($0.id, $0) })

            print("🔑 BookmarksRegistry загружен (\(trackBookmarks.count) треков, \(folderBookmarks.count) папок)")

        } catch {
            print("ℹ️ BookmarksRegistry: нет файла, создаём новый.")
            folderBookmarks = [:]
            trackBookmarks = [:]
        }
    }

    // MARK: - Сохранение

    func persist() {
        let file = BookmarkFile(
            folders: folderBookmarks.values.sorted { $0.updatedAt > $1.updatedAt },
            tracks:  trackBookmarks.values.sorted  { $0.updatedAt > $1.updatedAt }
        )

        do {
            let data = try encoder.encode(file)
            try data.write(to: fileURL, options: .atomic)
            print("💾 BookmarksRegistry сохранён")
        } catch {
            print("❌ Ошибка сохранения BookmarksRegistry:", error)
        }
    }

    // MARK: - Папки

    func upsertFolderBookmark(id: UUID, base64: String) {
        folderBookmarks[id] = FolderBookmark(
            id: id,
            base64: base64,
            updatedAt: Date()
        )
    }

    func removeFolderBookmark(id: UUID) {
        folderBookmarks.removeValue(forKey: id)
    }

    func folderBookmark(for id: UUID) -> String? {
        folderBookmarks[id]?.base64
    }

    // MARK: - Треки

    func upsertTrackBookmark(id: UUID, base64: String) {
        trackBookmarks[id] = TrackBookmark(
            id: id,
            base64: base64,
            updatedAt: Date()
        )
    }

    func removeTrackBookmark(id: UUID) {
        trackBookmarks.removeValue(forKey: id)
    }

    func trackBookmark(for id: UUID) -> String? {
        trackBookmarks[id]?.base64
    }
}
