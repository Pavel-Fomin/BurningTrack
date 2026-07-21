//
//  LibraryFileManager.swift
//  TrackList
//
//  Операции с физическими файлами треков:
//  - перемещение между папками фонотеки
//  - переименование файла трека
//
//  Работает поверх:
//  - BookmarksRegistry (bookmark'и файлов и папок)
//  - BookmarkResolver (URL из bookmark'ов)
//  - TrackRegistry (метаданные треков)
//  - PlayerManager (проверка, занят ли трек плеером)
//
//  Created by Pavel Fomin on 07.12.2025.
//

import Foundation

/// Ошибки файловых операций с треками.
enum LibraryFileError: Error {
    case trackIsPlaying
    case trackNotFound
    case sourceURLUnavailable
    case destinationFolderUnavailable
    case destinationAlreadyExists
    case moveFailed(underlying: Error)
    case bookmarkCreationFailed
    case relativePathFailed

}

/// Менеджер, отвечающий за операции с физическими файлами треков.
/// Не занимается UI и не знает про дерево LibraryFolder.
///
actor LibraryFileManager {

    // MARK: - Singleton

    static let shared = LibraryFileManager()

    private init() {}

    // MARK: - Перемещение файла

    /// - Parameters:
    ///   - trackId: ID трека (TrackRegistry / BookmarksRegistry).
    ///   - destinationFolderId: ID целевой папки (FolderEntry.id).
    ///   - playerManager: актуальный экземпляр PlayerManager для проверки занятости трека.
    func moveTrack(
        id trackId: UUID,
        toFolder destinationFolderId: UUID,
        using playerManager: PlayerManager
    ) async throws {

        // 1. Запрещаем перемещение файла, если он сейчас занят плеером.
        guard !playerManager.isBusy(trackId) else {
            throw LibraryFileError.trackIsPlaying
        }

        // 2. Берём метаданные трека
        guard let entry = await TrackRegistry.shared.entry(for: trackId) else {
            throw LibraryFileError.trackNotFound
        }

        // 3. Получаем исходный URL файла через bookmark трека
        guard let sourceURL = await BookmarkResolver.url(forTrack: trackId) else {
            throw LibraryFileError.sourceURLUnavailable
        }

        // 4. Получаем модель целевой папки из структуры фонотеки
        guard let destinationFolder = await MusicLibraryManager.shared.folder(for: destinationFolderId) else {
            throw LibraryFileError.destinationFolderUnavailable
        }

        // 5. Определяем прикреплённый корень, внутри которого находится целевая папка.
        // Bookmark существует только для корня, поэтому подпапку нельзя считать rootFolderId.
        guard let destinationRootFolder = await MusicLibraryManager.shared.rootFolder(for: destinationFolderId) else {
            throw LibraryFileError.destinationFolderUnavailable
        }

        let destinationFolderURL = destinationFolder.url
        let destinationRootFolderId = destinationRootFolder.id
        let destinationRootFolderURL = destinationRootFolder.url
        let fileName = entry.fileName
        let destinationURL = destinationFolderURL.appendingPathComponent(fileName)

        // Если путь не меняется — выходим тихо
        if sourceURL == destinationURL {
            print("ℹ️ moveTrack: исходный и целевой URL совпадают, операция пропущена")
            return
        }

        // 6. Проверяем, нет ли файла с таким именем в целевой папке
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            throw LibraryFileError.destinationAlreadyExists
        }

        // 7. Открываем security-scoped доступ
        // ВАЖНО:
        // - доступ к подпапкам НЕ требует отдельных bookmark'ов
        // - достаточно открыть доступ к исходному файлу и КОРНЕВОЙ папке назначения
        let sourceStarted = sourceURL.startAccessingSecurityScopedResource()

        let hasRuntimeDestinationRootAccess = await MusicLibraryManager.shared.hasActiveRootAccess(
            rootFolderId: destinationRootFolderId,
            url: destinationRootFolderURL
        )
        let destinationRootStarted = destinationRootFolderURL.startAccessingSecurityScopedResource()
        if !destinationRootStarted && hasRuntimeDestinationRootAccess == false {
            throw LibraryFileError.destinationFolderUnavailable
        }

        defer {
            if sourceStarted { sourceURL.stopAccessingSecurityScopedResource() }
            if destinationRootStarted {
                destinationRootFolderURL.stopAccessingSecurityScopedResource()
            }
        }

        // 8. Перемещаем файл
        do {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            print("✅ Файл перемещён:\n    from: \(sourceURL.path)\n      to: \(destinationURL.path)")
        } catch {
            throw LibraryFileError.moveFailed(underlying: error)
        }

        // 9. Создаём новый bookmark для обновлённого пути
        guard let newBookmarkBase64 = BookmarkResolver.makeBookmarkBase64(for: destinationURL) else {
            throw LibraryFileError.bookmarkCreationFailed
        }

        await BookmarksRegistry.shared.upsertTrackBookmark(
            id: trackId,
            base64: newBookmarkBase64
        )

        // 10. Строим новый relativePath относительно прикреплённого корня назначения.
        let newRelativePath = try makeRelativePath(
            fileURL: destinationURL,
            rootFolderURL: destinationRootFolderURL
        )
        // После перемещения размер обновляется из атрибута уже нового файла.
        let fileSize = LibraryFileSizeResolver.fileSize(for: destinationURL)

        // 11. Обновляем метаданные трека в реестре
        await TrackRegistry.shared.upsertTrack(
            id: trackId,
            fileName: fileName,
            relativePath: newRelativePath,
            folderId: destinationFolderId,
            rootFolderId: destinationRootFolderId,
            fileDate: entry.fileDate,
            fileSize: fileSize,
            shouldUpdateFileSize: true
        )

        // 12. Обновляем library identity:
        // старый путь убираем, новый путь привязываем к тому же trackId
        if entry.source == .library,
           let rootFolderId = entry.rootFolderId,
           let relativePath = entry.relativePath {
            try await TrackIdentityResolver.shared.unbindLibraryTrack(
                rootFolderId: rootFolderId,
                relativePath: relativePath
            )
        }

        try await TrackIdentityResolver.shared.bindLibraryTrack(
            id: trackId,
            rootFolderId: destinationRootFolderId,
            relativePath: newRelativePath
        )

        if entry.source == .imported {
            // После переноса imported-файла в фонотеку его path-identity больше не должен работать как imported.
            try await TrackIdentityResolver.shared.forgetTrack(id: trackId)
        }

        // Сохраняем изменения после физического перемещения файла.
        // Если запись реестров не прошла, операция не должна считаться успешной.
        try await BookmarksRegistry.shared.throwPendingPersistenceError()
        try await TrackRegistry.shared.throwPendingPersistenceError()
    }

    // MARK: - Переименование файла
  
    /// - Parameters:
    ///   - trackId: ID трека.
    ///   - newFileName: новое имя файла (желательно с расширением).
    ///   - playerManager: актуальный экземпляр PlayerManager.
    func renameTrack(
        id trackId: UUID,
        to newFileName: String,
        using playerManager: PlayerManager
    ) async throws {
        
        // 1. Запрещаем переименование файла, если он сейчас занят плеером.
        guard !playerManager.isBusy(trackId) else {
            throw LibraryFileError.trackIsPlaying
        }

        // 2. Берём метаданные трека
        guard let entry = await TrackRegistry.shared.entry(for: trackId) else {
            throw LibraryFileError.trackNotFound
        }
        
        // 3. URL файла через bookmark трека
        guard let sourceURL = await BookmarkResolver.url(forTrack: trackId) else {
            throw LibraryFileError.sourceURLUnavailable
        }
        
        let folderURL = sourceURL.deletingLastPathComponent()
        let destinationURL = folderURL.appendingPathComponent(newFileName)
        
        // Если имя не поменялось — ничего не делаем
        if sourceURL == destinationURL {
            print("ℹ️ renameTrack: исходный и целевой URL совпадают, операция пропущена")
            return
        }
        
        // Проверяем, нет ли файла с таким именем
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            throw LibraryFileError.destinationAlreadyExists
        }
        
        let sourceStarted = sourceURL.startAccessingSecurityScopedResource()
        let folderStarted = folderURL.startAccessingSecurityScopedResource()
        defer {
            if sourceStarted { sourceURL.stopAccessingSecurityScopedResource() }
            if folderStarted { folderURL.stopAccessingSecurityScopedResource() }
        }
        
        // 4. Переименовываем файл (move внутри той же папки)
        do {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            print("✅ Файл переименован:\n    from: \(sourceURL.lastPathComponent)\n      to: \(destinationURL.lastPathComponent)")
        } catch {
            throw LibraryFileError.moveFailed(underlying: error)
        }
        
        // 5. Новый bookmark для нового имени
        guard let newBookmarkBase64 = BookmarkResolver.makeBookmarkBase64(for: destinationURL) else {
            throw LibraryFileError.bookmarkCreationFailed
        }
        
        await BookmarksRegistry.shared.upsertTrackBookmark(
            id: trackId,
            base64: newBookmarkBase64
        )
        
        if entry.source == .library {
            // 6. Получаем rootURL, чтобы корректно пересчитать relativePath.
            guard let rootFolderId = entry.rootFolderId,
                  let folderId = entry.folderId,
                  let oldRelativePath = entry.relativePath,
                  let rootFolderURL = await BookmarkResolver.url(forFolder: rootFolderId)
            else {
                throw LibraryFileError.destinationFolderUnavailable
            }

            let newRelativePath = try makeRelativePath(
                fileURL: destinationURL,
                rootFolderURL: rootFolderURL
            )
            // После переименования размер обновляется из атрибута файла по новому URL.
            let fileSize = LibraryFileSizeResolver.fileSize(for: destinationURL)

            // 7. Обновляем реестры фонотеки.
            await TrackRegistry.shared.upsertTrack(
                id: trackId,
                fileName: newFileName,
                relativePath: newRelativePath,
                folderId: folderId,
                rootFolderId: rootFolderId,
                fileDate: entry.fileDate,
                fileSize: fileSize,
                shouldUpdateFileSize: true
            )

            // 8. Обновляем library identity:
            // старый путь убираем, новый путь привязываем к тому же trackId.
            try await TrackIdentityResolver.shared.unbindLibraryTrack(
                rootFolderId: rootFolderId,
                relativePath: oldRelativePath
            )

            try await TrackIdentityResolver.shared.bindLibraryTrack(
                id: trackId,
                rootFolderId: rootFolderId,
                relativePath: newRelativePath
            )
        } else {
            // 6. Imported-трек остаётся вне фонотеки: обновляем только SQLite metadata и imported identity.
            await TrackRegistry.shared.upsertImportedTrack(
                id: trackId,
                fileName: newFileName,
                fileURL: destinationURL,
                fileDate: entry.fileDate
            )

            try await TrackIdentityResolver.shared.replaceImportedTrackIdentity(
                id: trackId,
                url: destinationURL
            )
        }
        
        // Сохраняем изменения после физического переименования файла.
        // Если запись реестров не прошла, операция не должна считаться успешной.
        try await BookmarksRegistry.shared.throwPendingPersistenceError()
        try await TrackRegistry.shared.throwPendingPersistenceError()
    }
    
    // MARK: - Вспомогательное

    /// Строит relativePath файла относительно корневой папки фонотеки.
    private func makeRelativePath(
        fileURL: URL,
        rootFolderURL: URL
    ) throws -> String {
        let rootPath = rootFolderURL.standardizedFileURL.path.hasSuffix("/")
            ? rootFolderURL.standardizedFileURL.path
            : rootFolderURL.standardizedFileURL.path + "/"

        let filePath = fileURL.standardizedFileURL.path

        guard filePath.hasPrefix(rootPath) else {
            throw LibraryFileError.moveFailed(
                underlying: NSError(
                    domain: "LibraryFileManager",
                    code: 1001,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Файл оказался вне корневой папки фонотеки."
                    ]
                )
            )
        }

        return String(filePath.dropFirst(rootPath.count))
    }
}
