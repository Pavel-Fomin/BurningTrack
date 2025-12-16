//
//  TrackRegistry.swift
//  TrackList
//
//  Хранилище метаданных о папках и треках.
//  Без bookmark'ов, без FileManager, без рекурсий.
//  Только данные.
//
//  Created by Pavel Fomin on 30.11.2025.
//

import Foundation

actor TrackRegistry {

    // MARK: - Вложенные типы

    struct FolderEntry: Codable, Identifiable {
        var id: UUID
        var name: String
        var updatedAt: Date
    }

    struct TrackEntry: Codable, Identifiable {
        var id: UUID
        var fileName: String
        var folderId: UUID
        var rootFolderId: UUID
        var updatedAt: Date
    }

    struct RegistryFile: Codable {
        var folders: [FolderEntry]
        var tracks: [TrackEntry]
    }

    // MARK: - Свойства

    static let shared = TrackRegistry()

    private var folders: [UUID: FolderEntry] = [:]
    private var tracks: [UUID: TrackEntry] = [:]

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

    // MARK: - Загрузка

    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try decoder.decode(RegistryFile.self, from: data)

            folders = Dictionary(uniqueKeysWithValues:
                                    decoded.folders.map { ($0.id, $0) })

            tracks = Dictionary(uniqueKeysWithValues:
                                    decoded.tracks.map { ($0.id, $0) })

            print("📘 TrackRegistry загружен (\(tracks.count) треков, \(folders.count) папок)")

        } catch {
            print("ℹ️ TrackRegistry: нет файла, создаём новый.")
            folders = [:]
            tracks = [:]
        }
    }

    // MARK: - Сохранение

    func persist() {
        let file = RegistryFile(
            folders: folders.values.sorted { $0.updatedAt > $1.updatedAt },
            tracks: tracks.values.sorted { $0.updatedAt > $1.updatedAt }
        )

        do {
            let data = try encoder.encode(file)
            try data.write(to: fileURL, options: .atomic)
            print("💾 TrackRegistry сохранён")
        } catch {
            print("❌ Ошибка сохранения TrackRegistry:", error)
        }
    }

    // MARK: - Папки

    func upsertFolder(id: UUID, name: String) {
        let entry = FolderEntry(
            id: id,
            name: name,
            updatedAt: Date()
        )
        folders[id] = entry
    }

    func removeFolder(id: UUID) {
        folders.removeValue(forKey: id)

        // Удаляем треки, связанные с этой папкой
        tracks = tracks.filter { $0.value.rootFolderId != id }
    }

    func allFolders() -> [FolderEntry] {
        folders.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Треки

    func upsertTrack(
        id: UUID,
        fileName: String,
        folderId: UUID,
        rootFolderId: UUID
    ) {
        let entry = TrackEntry(
            id: id,
            fileName: fileName,
            folderId: folderId,
            rootFolderId: rootFolderId,
            updatedAt: Date()
        )
        tracks[id] = entry
    }

    func removeTrack(id: UUID) {
        tracks.removeValue(forKey: id)
    }

    func tracks(inFolder folderId: UUID) -> [TrackEntry] {
        tracks.values.filter { $0.folderId == folderId }
    }

    func allTracks() -> [TrackEntry] {
        Array(tracks.values)
    }

    func entry(for id: UUID) -> TrackEntry? {
        tracks[id]
    }
    
    func tracks(inRootFolder rootId: UUID) -> [TrackEntry] {
        tracks.values.filter { $0.rootFolderId == rootId }
    }
}
