//
//  LibraryDatabaseStore.swift
//  TrackList
//
//  SQLite-хранилище фонотеки.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

// Ошибки фасада фонотеки, которые не раскрывают детали SQLite верхним слоям.
enum LibraryDatabaseStoreError: Error {
    case rootFolderNotFound(UUID)
}

// Единый фасад фонотеки поверх типобезопасных SQLite Store.
final class LibraryDatabaseStore {
    private let executor: DatabaseExecutor
    private let folderStore: SQLiteFolderStore
    private let trackStore: SQLiteTrackStore
    private let metadataStore: SQLiteTrackMetadataStore

    init(executor: DatabaseExecutor) {
        self.executor = executor
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

    /// Возвращает все сохранённые папки фонотеки, включая подпапки.
    func fetchAllFolders() throws -> [FolderDatabaseModel] {
        try folderStore.fetchAll()
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

        try executor.transaction { _ in
            let existing = try folderStore.fetch(id: id)

            if existing == nil {
                try shiftRootFoldersDown(updatedAt: now)
            }

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
                sortOrder: existing == nil ? 0 : existing?.sortOrder,
                lastScannedAt: existing?.lastScannedAt,
                trackSortMode: existing?.trackSortMode
            )

            try folderStore.upsert(model)
        }
    }

    /// Обновляет bookmark корневой папки, создавая строку-заготовку при bootstrap.
    func upsertRootFolderBookmark(
        id: UUID,
        bookmarkBase64: String
    ) throws {
        let now = Date()

        try executor.transaction { _ in
            if let existing = try folderStore.fetch(id: id) {
                var updated = existing
                updated.bookmarkBase64 = bookmarkBase64
                updated.updatedAt = now
                try folderStore.upsert(updated)
                return
            }

            try shiftRootFoldersDown(updatedAt: now)

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
                sortOrder: 0,
                lastScannedAt: nil,
                trackSortMode: nil
            )

            try folderStore.upsert(model)
        }
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

    /// Возвращает сохранённый режим сортировки треков конкретной папки.
    func libraryTrackSortMode(forFolderId folderId: UUID) throws -> LibraryTrackSortMode {
        guard let rawValue = try folderStore.fetch(id: folderId)?.trackSortMode else {
            return .fileDateDesc
        }

        return LibraryTrackSortMode(rawValue: rawValue) ?? .fileDateDesc
    }

    /// Сохраняет режим сортировки треков только для указанной папки фонотеки.
    func updateLibraryTrackSortMode(
        _ mode: LibraryTrackSortMode,
        forFolderId folderId: UUID
    ) throws {
        try folderStore.updateTrackSortMode(
            id: folderId,
            trackSortMode: mode.rawValue,
            updatedAt: Date()
        )
    }

    /// Сохраняет фактический порядок корневых папок фонотеки в sort_order.
    func updateRootFoldersOrder(_ orderedIds: [UUID]) throws {
        let updatedAt = Date()

        try executor.transaction { _ in
            var seenIds = Set<UUID>()
            let uniqueOrderedIds = orderedIds.filter { id in
                seenIds.insert(id).inserted
            }
            let rootFolders = try folderStore.fetchRootFolders()
            let rootFoldersById = Dictionary(
                uniqueKeysWithValues: rootFolders.map { ($0.id, $0) }
            )

            for id in uniqueOrderedIds {
                guard rootFoldersById[id]?.isRoot == true else {
                    throw LibraryDatabaseStoreError.rootFolderNotFound(id)
                }
            }

            // Root-папки, которых нет в текущем UI-порядке, сохраняются в конце без потери прежней очередности.
            let trailingIds = rootFolders
                .filter { seenIds.contains($0.id) == false }
                .map(\.id)
            let normalizedIds = uniqueOrderedIds + trailingIds

            for (index, id) in normalizedIds.enumerated() {
                try folderStore.updateSortOrder(
                    id: id,
                    sortOrder: index,
                    updatedAt: updatedAt
                )
            }
        }
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

    /// Возвращает краткие сохранённые metadata для списка треков фонотеки.
    func fetchCachedMetadata(trackIds: [UUID]) throws -> [TrackCachedMetadata] {
        try metadataStore.fetchAll(trackIds: trackIds).map { model in
            TrackCachedMetadata(
                trackId: model.trackId,
                title: model.title,
                artist: model.artist,
                album: model.album,
                duration: model.duration,
                year: model.year,
                label: model.label,
                genre: model.genre,
                comment: model.comment
            )
        }
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
            sortOrder: 0,
            lastScannedAt: nil,
            trackSortMode: nil
        )

        try shiftRootFoldersDown(updatedAt: now)
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
            sortOrder: nil,
            lastScannedAt: nil,
            trackSortMode: nil
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

    /// Сдвигает текущие корневые папки вниз перед вставкой нового root наверх.
    private func shiftRootFoldersDown(updatedAt: Date) throws {
        let rootFolders = try folderStore.fetchRootFolders()

        for (index, var model) in rootFolders.enumerated() {
            // Текущий fetchRootFolders-порядок становится базовым порядком для старых записей без sort_order.
            model.sortOrder = index + 1
            model.updatedAt = updatedAt
            try folderStore.upsert(model)
        }
    }
}
