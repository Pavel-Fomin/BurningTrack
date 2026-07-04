//
//  TrackRegistry.swift
//  TrackList
//
//  Хранилище метаданных о папках и треках.
//  Для фонотеки использует SQLite, для внефазовых одиночных импортов сохраняет legacy JSON.
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
        var relativePath: String
        var folderId: UUID
        var rootFolderId: UUID
        /// Дата первого появления трека в фонотеке.
        var importedAt: Date
        /// Дата файла для сортировки и группировки фонотеки.
        var fileDate: Date
        var updatedAt: Date
        /// Сохранённое состояние доступности файла.
        var isAvailable: Bool

        enum CodingKeys: String, CodingKey {
            case id, fileName, relativePath, folderId, rootFolderId, importedAt, fileDate, updatedAt, isAvailable
        }

        init(
            id: UUID,
            fileName: String,
            relativePath: String,
            folderId: UUID,
            rootFolderId: UUID,
            importedAt: Date,
            fileDate: Date,
            updatedAt: Date,
            isAvailable: Bool = true
        ) {
            self.id = id
            self.fileName = fileName
            self.relativePath = relativePath
            self.folderId = folderId
            self.rootFolderId = rootFolderId
            self.importedAt = importedAt
            self.fileDate = fileDate
            self.updatedAt = updatedAt
            self.isAvailable = isAvailable
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(UUID.self, forKey: .id)
            fileName = try c.decode(String.self, forKey: .fileName)
            relativePath = (try? c.decode(String.self, forKey: .relativePath)) ?? ""
            folderId = try c.decode(UUID.self, forKey: .folderId)
            rootFolderId = try c.decode(UUID.self, forKey: .rootFolderId)
            updatedAt = try c.decode(Date.self, forKey: .updatedAt)
            importedAt = (try? c.decode(Date.self, forKey: .importedAt)) ?? updatedAt
            fileDate = (try? c.decode(Date.self, forKey: .fileDate)) ?? importedAt
            isAvailable = (try? c.decode(Bool.self, forKey: .isAvailable)) ?? true
        }
    }

    struct RegistryFile: Codable {
        var folders: [FolderEntry]
        var tracks: [TrackEntry]
    }

    // MARK: - Свойства

    static let shared = TrackRegistry()

    private var legacyImportedTracks: [UUID: TrackEntry] = [:]
    private var backupFolders: [FolderEntry] = []
    private var backupLibraryTracks: [TrackEntry] = []
    private var isLegacyLoaded = false
    private var legacyDirty = false
    private var pendingPersistenceError: Error?
    private var cachedLibraryStore: LibraryDatabaseStore?

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
        // JSON больше не является источником фонотеки, поэтому из него берём только legacy-импорты.
        isLegacyLoaded = false
        loadLegacyIfNeeded()

        let libraryCounts = (try? libraryStore().fetchRootFolders().count) ?? 0
        print("📘 TrackRegistry загружен из SQLite (папок: \(libraryCounts), legacy imports: \(legacyImportedTracks.count))")
    }

    // MARK: - Сохранение

    func persist() throws {
        if let pendingPersistenceError {
            self.pendingPersistenceError = nil
            throw pendingPersistenceError
        }

        guard legacyDirty else {
            print(" TrackRegistry: SQLite-изменения уже сохранены")
            return
        }

        let file = RegistryFile(
            folders: backupFolders,
            tracks: backupLibraryTracks + legacyImportedTracks.values.sorted { $0.updatedAt > $1.updatedAt }
        )

        // Legacy JSON пишется только для внефазовых импортов и сохраняет старые backup-записи фонотеки.
        let data = try encoder.encode(file)
        try data.write(to: fileURL, options: .atomic)
        legacyDirty = false
        print(" TrackRegistry legacy imports сохранены")
    }

    // MARK: - Папки

    func upsertFolder(id: UUID, name: String) {
        do {
            try libraryStore().upsertRootFolder(
                id: id,
                name: name
            )
        } catch {
            rememberPersistenceError(error)
        }
    }

    /// Удаляет корневую папку и все связанные с ней SQLite-записи фонотеки.
    func removeFolder(id rootFolderId: UUID) {
        do {
            try libraryStore().deleteRootFolder(id: rootFolderId)
        } catch {
            rememberPersistenceError(error)
        }
    }

    func allFolders() -> [FolderEntry] {
        do {
            return try libraryStore()
                .fetchRootFolders()
                .map(folderEntry(from:))
        } catch {
            rememberPersistenceError(error)
            return []
        }
    }

    func updateFolderAvailability(
        id: UUID,
        isAvailable: Bool
    ) {
        do {
            try libraryStore().updateFolderAvailability(
                id: id,
                isAvailable: isAvailable
            )
        } catch {
            rememberPersistenceError(error)
        }
    }

    // MARK: - Треки

    func upsertTrack(
        id: UUID,
        fileName: String,
        relativePath: String,
        folderId: UUID,
        rootFolderId: UUID,
        fileDate: Date = Date()
    ) {
        if isLibraryRelativePath(relativePath) {
            do {
                try libraryStore().upsertLibraryTrack(
                    id: id,
                    fileName: fileName,
                    relativePath: relativePath,
                    folderId: folderId,
                    rootFolderId: rootFolderId,
                    fileDate: fileDate
                )
            } catch {
                rememberPersistenceError(error)
            }
            return
        }

        loadLegacyIfNeeded()

        let now = Date()
        let existing = legacyImportedTracks[id]
        let entry = TrackEntry(
            id: id,
            fileName: fileName,
            relativePath: relativePath,
            folderId: folderId,
            rootFolderId: rootFolderId,
            importedAt: existing?.importedAt ?? now,
            fileDate: fileDate,
            updatedAt: now,
            isAvailable: true
        )
        legacyImportedTracks[id] = entry
        legacyDirty = true
    }

    func removeTrack(id: UUID) {
        loadLegacyIfNeeded()

        if legacyImportedTracks.removeValue(forKey: id) != nil {
            legacyDirty = true
            return
        }

        do {
            try libraryStore().removeLibraryTrack(id: id)
        } catch {
            rememberPersistenceError(error)
        }
    }

    func tracks(inFolder folderId: UUID) -> [TrackEntry] {
        do {
            return try libraryStore()
                .fetchLibraryTracks(inFolder: folderId)
                .compactMap(trackEntry(from:))
        } catch {
            rememberPersistenceError(error)
            return []
        }
    }

    func tracks(inRootFolder rootFolderId: UUID) -> [TrackEntry] {
        do {
            return try libraryStore()
                .fetchLibraryTracks(inRootFolder: rootFolderId)
                .compactMap(trackEntry(from:))
        } catch {
            rememberPersistenceError(error)
            return []
        }
    }

    func allTracks() -> [TrackEntry] {
        loadLegacyIfNeeded()

        let libraryTracks: [TrackEntry]
        do {
            libraryTracks = try libraryStore()
                .fetchRootFolders()
                .flatMap { root in
                    try libraryStore()
                        .fetchLibraryTracks(inRootFolder: root.id)
                        .compactMap(trackEntry(from:))
                }
        } catch {
            rememberPersistenceError(error)
            libraryTracks = []
        }

        return libraryTracks + Array(legacyImportedTracks.values)
    }

    func entry(for id: UUID) -> TrackEntry? {
        do {
            if let model = try libraryStore().fetchLibraryTrack(id: id) {
                return trackEntry(from: model)
            }
        } catch {
            rememberPersistenceError(error)
        }

        loadLegacyIfNeeded()
        return legacyImportedTracks[id]
    }
    
    func entry(
        inRootFolder rootFolderId: UUID,
        relativePath: String
    ) -> TrackEntry? {
        do {
            if let model = try libraryStore().fetchLibraryTrack(
                rootFolderId: rootFolderId,
                relativePath: relativePath
            ) {
                return trackEntry(from: model)
            }
        } catch {
            rememberPersistenceError(error)
        }

        loadLegacyIfNeeded()
        return legacyImportedTracks.values.first {
            $0.rootFolderId == rootFolderId &&
            $0.relativePath == relativePath
        }
    }

    func updateTrackAvailability(
        id: UUID,
        isAvailable: Bool
    ) {
        loadLegacyIfNeeded()

        if var legacyEntry = legacyImportedTracks[id] {
            legacyEntry.isAvailable = isAvailable
            legacyEntry.updatedAt = Date()
            legacyImportedTracks[id] = legacyEntry
            legacyDirty = true
            return
        }

        do {
            try libraryStore().updateTrackAvailability(
                id: id,
                isAvailable: isAvailable
            )
        } catch {
            rememberPersistenceError(error)
        }
    }

    func isLibraryTrack(id: UUID) -> Bool {
        do {
            return try libraryStore().fetchLibraryTrack(id: id) != nil
        } catch {
            rememberPersistenceError(error)
            return false
        }
    }

    func isLegacyImportedTrack(id: UUID) -> Bool {
        loadLegacyIfNeeded()
        return legacyImportedTracks[id] != nil
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
            let decoded = try decoder.decode(RegistryFile.self, from: data)

            backupFolders = decoded.folders
            backupLibraryTracks = decoded.tracks.filter { isLibraryRelativePath($0.relativePath) }
            legacyImportedTracks = Dictionary(
                uniqueKeysWithValues: decoded.tracks
                    .filter { isLibraryRelativePath($0.relativePath) == false }
                    .map { ($0.id, $0) }
            )
        } catch {
            backupFolders = []
            backupLibraryTracks = []
            legacyImportedTracks = [:]
        }
    }

    private func folderEntry(from model: FolderDatabaseModel) -> FolderEntry {
        FolderEntry(
            id: model.id,
            name: model.name,
            updatedAt: model.updatedAt
        )
    }

    private func trackEntry(from model: TrackDatabaseModel) -> TrackEntry? {
        guard let folderId = model.folderId,
              let rootFolderId = model.rootFolderId,
              let relativePath = model.relativePath
        else {
            return nil
        }

        return TrackEntry(
            id: model.id,
            fileName: model.fileName,
            relativePath: relativePath,
            folderId: folderId,
            rootFolderId: rootFolderId,
            importedAt: model.importedAt,
            fileDate: model.fileDate ?? model.importedAt,
            updatedAt: model.updatedAt,
            isAvailable: model.isAvailable
        )
    }

    private func isLibraryRelativePath(_ relativePath: String) -> Bool {
        relativePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func rememberPersistenceError(_ error: Error) {
        pendingPersistenceError = error
        PersistentLogger.log("❌ TrackRegistry SQLite error: \(error)")
    }
}
