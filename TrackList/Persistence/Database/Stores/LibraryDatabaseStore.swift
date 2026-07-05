//
//  LibraryDatabaseStore.swift
//  TrackList
//
//  SQLite-хранилище фонотеки.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

// Единый фасад фонотеки поверх типобезопасных SQLite Store.
final class LibraryDatabaseStore {
    private let folderStore: SQLiteFolderStore
    private let trackStore: SQLiteTrackStore
    private let metadataStore: SQLiteTrackMetadataStore

    init(executor: DatabaseExecutor) {
        self.folderStore = SQLiteFolderStore(executor: executor)
        self.trackStore = SQLiteTrackStore(executor: executor)
        self.metadataStore = SQLiteTrackMetadataStore(executor: executor)
    }

    convenience init(database: AppDatabase = .shared) throws {
        try self.init(executor: database.databaseExecutor())
    }

    // MARK: - Folders

    /// Возвращает прикреплённые корневые папки фонотеки.
    func fetchRootFolders() throws -> [FolderDatabaseModel] {
        try folderStore.fetchRootFolders()
    }

    /// Возвращает папку фонотеки по идентификатору.
    func fetchFolder(id: UUID) throws -> FolderDatabaseModel? {
        try folderStore.fetch(id: id)
    }

    /// Создаёт или обновляет корневую папку, сохраняя существующий bookmark.
    func upsertRootFolder(
        id: UUID,
        name: String,
        bookmarkBase64: String? = nil,
        isAvailable: Bool = true
    ) throws {
        let now = Date()
        let existing = try folderStore.fetch(id: id)
        let model = FolderDatabaseModel(
            id: id,
            parentFolderId: nil,
            rootFolderId: nil,
            name: name,
            relativePath: "",
            bookmarkBase64: bookmarkBase64 ?? existing?.bookmarkBase64,
            isRoot: true,
            isAvailable: isAvailable,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            lastScannedAt: existing?.lastScannedAt
        )

        try folderStore.upsert(model)
    }

    /// Обновляет bookmark корневой папки, создавая строку-заготовку при bootstrap.
    func upsertRootFolderBookmark(
        id: UUID,
        bookmarkBase64: String
    ) throws {
        let now = Date()

        if let existing = try folderStore.fetch(id: id) {
            var updated = existing
            updated.bookmarkBase64 = bookmarkBase64
            updated.updatedAt = now
            try folderStore.upsert(updated)
            return
        }

        let model = FolderDatabaseModel(
            id: id,
            parentFolderId: nil,
            rootFolderId: nil,
            name: "",
            relativePath: "",
            bookmarkBase64: bookmarkBase64,
            isRoot: true,
            isAvailable: true,
            createdAt: now,
            updatedAt: now,
            lastScannedAt: nil
        )

        try folderStore.upsert(model)
    }

    /// Возвращает bookmark корневой папки.
    func folderBookmark(id: UUID) throws -> String? {
        try folderStore.fetch(id: id)?.bookmarkBase64
    }

    /// Убирает bookmark корневой папки без удаления строки папки.
    func removeFolderBookmark(id: UUID) throws {
        try folderStore.updateBookmark(
            id: id,
            bookmarkBase64: nil,
            updatedAt: Date()
        )
    }

    /// Удаляет корневую папку фонотеки вместе с дочерними SQLite-записями.
    func deleteRootFolder(id: UUID) throws {
        try folderStore.delete(id: id)
    }

    /// Сохраняет актуальное состояние доступности папки.
    func updateFolderAvailability(
        id: UUID,
        isAvailable: Bool
    ) throws {
        try folderStore.updateAvailability(
            id: id,
            isAvailable: isAvailable,
            updatedAt: Date()
        )
    }

    // MARK: - Tracks

    /// Возвращает один активный трек фонотеки.
    func fetchLibraryTrack(id: UUID) throws -> TrackDatabaseModel? {
        try trackStore.fetchLibrary(id: id)
    }

    /// Возвращает один активный локальный трек приложения: library или imported.
    func fetchTrack(id: UUID) throws -> TrackDatabaseModel? {
        try trackStore.fetchActiveLocal(id: id)
    }

    /// Возвращает один активный одиночный imported-трек.
    func fetchImportedTrack(id: UUID) throws -> TrackDatabaseModel? {
        try trackStore.fetchImported(id: id)
    }

    /// Возвращает активный трек фонотеки по логическому пути внутри root-папки.
    func fetchLibraryTrack(
        rootFolderId: UUID,
        relativePath: String
    ) throws -> TrackDatabaseModel? {
        try trackStore.fetchLibrary(
            rootFolderId: rootFolderId,
            relativePath: relativePath
        )
    }

    /// Возвращает активные треки, которые лежат непосредственно в папке.
    func fetchLibraryTracks(inFolder folderId: UUID) throws -> [TrackDatabaseModel] {
        try trackStore.fetchLibraryTracks(inFolder: folderId)
    }

    /// Возвращает активные треки внутри всего прикреплённого корня.
    func fetchLibraryTracks(inRootFolder rootFolderId: UUID) throws -> [TrackDatabaseModel] {
        try trackStore.fetchLibraryTracks(inRootFolder: rootFolderId)
    }

    /// Возвращает все активные локальные треки приложения.
    func fetchAllTracks() throws -> [TrackDatabaseModel] {
        try trackStore.fetchAllActiveLocal()
    }

    /// Создаёт или обновляет трек фонотеки и служебную строку его папки.
    func upsertLibraryTrack(
        id: UUID,
        fileName: String,
        relativePath: String,
        folderId: UUID,
        rootFolderId: UUID,
        fileDate: Date,
        bookmarkBase64: String? = nil,
        isAvailable: Bool = true
    ) throws {
        try ensureRootFolder(id: rootFolderId)
        try ensureContainingFolder(
            folderId: folderId,
            rootFolderId: rootFolderId,
            trackRelativePath: relativePath
        )

        let now = Date()
        let existing = try trackStore.fetch(id: id)
        let model = TrackDatabaseModel(
            id: id,
            source: .library,
            folderId: folderId,
            rootFolderId: rootFolderId,
            fileName: fileName,
            relativePath: relativePath,
            fileExtension: (fileName as NSString).pathExtension.lowercased(),
            fileSize: existing?.fileSize,
            fileDate: fileDate,
            importedAt: existing?.importedAt ?? now,
            updatedAt: now,
            bookmarkBase64: bookmarkBase64 ?? existing?.bookmarkBase64,
            assetURLString: nil,
            isAvailable: isAvailable,
            isDeleted: false
        )

        try trackStore.upsert(model)
    }

    /// Создаёт или обновляет одиночный imported-трек без фиктивных folder/root-ссылок.
    func upsertImportedTrack(
        id: UUID,
        fileName: String,
        fileURL: URL? = nil,
        fileDate: Date = Date(),
        bookmarkBase64: String? = nil,
        isAvailable: Bool = true
    ) throws {
        let now = Date()
        let existing = try trackStore.fetch(id: id)
        let resolvedFileURL = fileURL?.standardizedFileURL
        let model = TrackDatabaseModel(
            id: id,
            source: .imported,
            folderId: nil,
            rootFolderId: nil,
            fileName: fileName,
            relativePath: nil,
            fileExtension: (fileName as NSString).pathExtension.lowercased(),
            fileSize: existing?.fileSize,
            fileDate: fileDate,
            importedAt: existing?.importedAt ?? now,
            updatedAt: now,
            bookmarkBase64: bookmarkBase64 ?? existing?.bookmarkBase64,
            assetURLString: resolvedFileURL?.absoluteString ?? existing?.assetURLString,
            isAvailable: isAvailable,
            isDeleted: false
        )

        try trackStore.upsert(model)
    }

    /// Обновляет bookmark локального трека приложения.
    func upsertTrackBookmark(
        id: UUID,
        bookmarkBase64: String
    ) throws {
        try trackStore.updateBookmark(
            id: id,
            bookmarkBase64: bookmarkBase64,
            updatedAt: Date()
        )
    }

    /// Возвращает bookmark локального трека приложения.
    func trackBookmark(id: UUID) throws -> String? {
        try trackStore.fetchActiveLocal(id: id)?.bookmarkBase64
    }

    /// Убирает bookmark трека, не удаляя саму строку индекса.
    func removeTrackBookmark(id: UUID) throws {
        try trackStore.updateBookmark(
            id: id,
            bookmarkBase64: nil,
            updatedAt: Date()
        )
    }

    /// Скрывает локальный трек приложения из активного индекса и удаляет его сохранённые metadata.
    func removeTrack(id: UUID) throws {
        try metadataStore.delete(trackId: id)
        try trackStore.markDeleted(id: id, updatedAt: Date())
    }

    /// Сохраняет актуальное состояние доступности трека.
    func updateTrackAvailability(
        id: UUID,
        isAvailable: Bool
    ) throws {
        try trackStore.updateAvailability(
            id: id,
            isAvailable: isAvailable,
            updatedAt: Date()
        )
    }

    // MARK: - Metadata

    /// Возвращает сохранённые metadata трека.
    func fetchTrackMetadata(trackId: UUID) throws -> TrackMetadataDatabaseModel? {
        try metadataStore.fetch(trackId: trackId)
    }

    /// Создаёт или обновляет сохранённые metadata трека.
    func upsertTrackMetadata(_ model: TrackMetadataDatabaseModel) throws {
        try metadataStore.upsert(model)
    }

    // MARK: - Helpers

    /// Создаёт минимальную root-строку, если синхронизация пришла раньше полного attach-flow.
    private func ensureRootFolder(id: UUID) throws {
        guard try folderStore.fetch(id: id) == nil else { return }

        let now = Date()
        let model = FolderDatabaseModel(
            id: id,
            parentFolderId: nil,
            rootFolderId: nil,
            name: "",
            relativePath: "",
            bookmarkBase64: nil,
            isRoot: true,
            isAvailable: true,
            createdAt: now,
            updatedAt: now,
            lastScannedAt: nil
        )

        try folderStore.upsert(model)
    }

    /// Создаёт строку подпапки, чтобы tracks.folder_id всегда ссылался на SQLite.
    private func ensureContainingFolder(
        folderId: UUID,
        rootFolderId: UUID,
        trackRelativePath: String
    ) throws {
        guard folderId != rootFolderId else { return }
        guard try folderStore.fetch(id: folderId) == nil else { return }

        let folderRelativePath = relativeFolderPath(forTrackRelativePath: trackRelativePath)
        let folderName = (folderRelativePath as NSString).lastPathComponent
        let now = Date()
        let model = FolderDatabaseModel(
            id: folderId,
            parentFolderId: nil,
            rootFolderId: rootFolderId,
            name: folderName.isEmpty ? "" : folderName,
            relativePath: folderRelativePath,
            bookmarkBase64: nil,
            isRoot: false,
            isAvailable: true,
            createdAt: now,
            updatedAt: now,
            lastScannedAt: nil
        )

        try folderStore.upsert(model)
    }

    /// Получает путь папки из относительного пути файла.
    private func relativeFolderPath(forTrackRelativePath relativePath: String) -> String {
        let folderPath = (relativePath as NSString).deletingLastPathComponent

        if folderPath == "." {
            return ""
        }

        return folderPath
    }
}
