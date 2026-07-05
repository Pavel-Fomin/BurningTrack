//
//  TrackRegistry.swift
//  TrackList
//
//  Хранилище метаданных о папках и локальных треках приложения.
//  Фонотека и одиночные imported-треки используют SQLite.
//
//  Created by Pavel Fomin on 30.11.2025.
//

import Foundation

actor TrackRegistry {

    // MARK: - Вложенные типы

    struct FolderEntry: Identifiable {
        var id: UUID
        var name: String
        var updatedAt: Date
    }

    struct TrackEntry: Identifiable {
        var id: UUID
        var source: TrackSource
        var fileName: String
        var relativePath: String?
        var folderId: UUID?
        var rootFolderId: UUID?
        /// Дата первого появления трека в локальном индексе приложения.
        var importedAt: Date
        /// Дата файла для сортировки и группировки фонотеки.
        var fileDate: Date
        var updatedAt: Date
        /// Сохранённое состояние доступности файла.
        var isAvailable: Bool

        init(
            id: UUID,
            source: TrackSource = .library,
            fileName: String,
            relativePath: String?,
            folderId: UUID?,
            rootFolderId: UUID?,
            importedAt: Date,
            fileDate: Date,
            updatedAt: Date,
            isAvailable: Bool = true
        ) {
            self.id = id
            self.source = source
            self.fileName = fileName
            self.relativePath = relativePath
            self.folderId = folderId
            self.rootFolderId = rootFolderId
            self.importedAt = importedAt
            self.fileDate = fileDate
            self.updatedAt = updatedAt
            self.isAvailable = isAvailable
        }
    }

    // MARK: - Свойства

    static let shared = TrackRegistry()

    private var pendingPersistenceError: Error?
    private var cachedLibraryStore: LibraryDatabaseStore?
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    // MARK: - Загрузка

    func load() {
        let libraryCounts = (try? libraryStore().fetchRootFolders().count) ?? 0
        let tracksCount = (try? libraryStore().fetchAllTracks().count) ?? 0
        print("📘 TrackRegistry загружен из SQLite (папок: \(libraryCounts), треков: \(tracksCount))")
    }

    // MARK: - Ошибки записи

    func throwPendingPersistenceError() throws {
        if let pendingPersistenceError {
            self.pendingPersistenceError = nil
            throw pendingPersistenceError
        }
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

        upsertImportedTrack(
            id: id,
            fileName: fileName,
            fileDate: fileDate
        )
    }

    func upsertImportedTrack(
        id: UUID,
        fileName: String,
        fileURL: URL? = nil,
        fileDate: Date = Date(),
        isAvailable: Bool = true
    ) {
        do {
            try libraryStore().upsertImportedTrack(
                id: id,
                fileName: fileName,
                fileURL: fileURL,
                fileDate: fileDate,
                isAvailable: isAvailable
            )
        } catch {
            rememberPersistenceError(error)
        }
    }

    func removeTrack(id: UUID) {
        do {
            try libraryStore().removeTrack(id: id)
        } catch {
            rememberPersistenceError(error)
        }
    }

    func tracks(inFolder folderId: UUID) -> [TrackEntry] {
        do {
            return try libraryStore()
                .fetchLibraryTracks(inFolder: folderId)
                .map(trackEntry(from:))
        } catch {
            rememberPersistenceError(error)
            return []
        }
    }

    func tracks(inRootFolder rootFolderId: UUID) -> [TrackEntry] {
        do {
            return try libraryStore()
                .fetchLibraryTracks(inRootFolder: rootFolderId)
                .map(trackEntry(from:))
        } catch {
            rememberPersistenceError(error)
            return []
        }
    }

    func allTracks() -> [TrackEntry] {
        do {
            return try libraryStore()
                .fetchAllTracks()
                .map(trackEntry(from:))
        } catch {
            rememberPersistenceError(error)
            return []
        }
    }

    func entry(for id: UUID) -> TrackEntry? {
        do {
            return try libraryStore()
                .fetchTrack(id: id)
                .map(trackEntry(from:))
        } catch {
            rememberPersistenceError(error)
            return nil
        }
    }
    
    func entry(
        inRootFolder rootFolderId: UUID,
        relativePath: String
    ) -> TrackEntry? {
        do {
            return try libraryStore().fetchLibraryTrack(
                rootFolderId: rootFolderId,
                relativePath: relativePath
            ).map(trackEntry(from:))
        } catch {
            rememberPersistenceError(error)
            return nil
        }
    }

    func updateTrackAvailability(
        id: UUID,
        isAvailable: Bool
    ) {
        do {
            try libraryStore().updateTrackAvailability(
                id: id,
                isAvailable: isAvailable
            )
        } catch {
            rememberPersistenceError(error)
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

    private func folderEntry(from model: FolderDatabaseModel) -> FolderEntry {
        FolderEntry(
            id: model.id,
            name: model.name,
            updatedAt: model.updatedAt
        )
    }

    private func trackEntry(from model: TrackDatabaseModel) -> TrackEntry {
        return TrackEntry(
            id: model.id,
            source: TrackSourceDatabaseMapper.trackSource(from: model.source),
            fileName: model.fileName,
            relativePath: model.relativePath,
            folderId: model.folderId,
            rootFolderId: model.rootFolderId,
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
