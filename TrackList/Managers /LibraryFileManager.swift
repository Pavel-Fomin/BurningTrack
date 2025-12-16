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
enum LibraryFileError: LocalizedError {
    case trackIsPlaying
    case trackNotFound
    case sourceURLUnavailable
    case destinationFolderUnavailable
    case destinationAlreadyExists
    case moveFailed(underlying: Error)
    case bookmarkCreationFailed

    var errorDescription: String? {
        switch self {
        case .trackIsPlaying:
            return "Трек сейчас воспроизводится. Остановите плеер, чтобы переместить или переименовать файл."
        case .trackNotFound:
            return "Трек не найден в реестре."
        case .sourceURLUnavailable:
            return "Не удалось получить исходный URL файла."
        case .destinationFolderUnavailable:
            return "Не удалось получить URL целевой папки."
        case .destinationAlreadyExists:
            return "В целевой папке уже существует файл с таким именем."
        case .moveFailed(let underlying):
            return "Не удалось выполнить файловую операцию: \(underlying.localizedDescription)"
        case .bookmarkCreationFailed:
            return "Не удалось создать новый bookmark для файла."
        }
    }
}

/// Менеджер, отвечающий за операции с физическими файлами треков.
/// Не занимается UI и не знает про дерево LibraryFolder.
///
actor LibraryFileManager {

    // MARK: - Singleton

    static let shared = LibraryFileManager()

    private init() {}

    // MARK: - Перемещает трек в другую папку фонотеки

    /// - Parameters:
    ///   - trackId: ID трека (TrackRegistry / BookmarksRegistry).
    ///   - destinationFolderId: ID целевой папки (FolderEntry.id).
    ///   - playerManager: актуальный экземпляр PlayerManager для проверки занятости трека.
    func moveTrack(
        id trackId: UUID,
        toFolder destinationFolderId: UUID,
        using playerManager: PlayerManager
    ) async throws {
        
        // 1. Проверяем, не занят ли трек плеером
        if playerManager.isBusy(trackId) {
            print("🚫 Нельзя переместить трек \(trackId) — он сейчас воспроизводится.")
            throw LibraryFileError.trackIsPlaying
        }

        // 2. Берём метаданные трека
        guard let entry = await TrackRegistry.shared.entry(for: trackId) else {
            print("❌ TrackRegistry: трек \(trackId) не найден")
            throw LibraryFileError.trackNotFound
        }

        // 3. Получаем исходный URL файла через bookmark трека
        guard let sourceURL = await BookmarkResolver.url(forTrack: trackId) else {
            print("❌ Не удалось восстановить URL файла для трека \(trackId)")
            throw LibraryFileError.sourceURLUnavailable
        }

        // 4. Получаем URL целевой папки
        guard let destinationFolderURL = await BookmarkResolver.url(forFolder: destinationFolderId) else {
            print("❌ Не удалось восстановить URL целевой папки для id \(destinationFolderId)")
            throw LibraryFileError.destinationFolderUnavailable
        }

        let fileName = entry.fileName
        let destinationURL = destinationFolderURL.appendingPathComponent(fileName)

        // Если путь не меняется — выходим тихо
        if sourceURL == destinationURL {
            print("ℹ️ moveTrack: исходный и целевой URL совпадают, операция пропущена")
            return
        }

        // 5. Проверяем, нет ли файла с таким именем в целевой папке
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            print("⚠️ В целевой папке уже есть файл \(fileName)")
            throw LibraryFileError.destinationAlreadyExists
        }

        // 6. Открываем security-scoped доступ к файлам и папкам
        let sourceStarted = sourceURL.startAccessingSecurityScopedResource()
        let destStarted = destinationFolderURL.startAccessingSecurityScopedResource()
        defer {
            if sourceStarted { sourceURL.stopAccessingSecurityScopedResource() }
            if destStarted { destinationFolderURL.stopAccessingSecurityScopedResource() }
        }

        // 7. Перемещаем файл
        do {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            print("✅ Файл перемещён:\n    from: \(sourceURL.path)\n      to: \(destinationURL.path)")
        } catch {
            print("❌ Ошибка перемещения файла: \(error)")
            throw LibraryFileError.moveFailed(underlying: error)
        }

        // 8. Создаём новый bookmark для обновлённого пути
        guard let newBookmarkBase64 = BookmarkResolver.makeBookmarkBase64(for: destinationURL) else {
            print("❌ Не удалось создать bookmark для нового пути файла")
            throw LibraryFileError.bookmarkCreationFailed
        }

        // 9. Обновляем BookmarksRegistry и TrackRegistry
        await BookmarksRegistry.shared.upsertTrackBookmark(id: trackId, base64: newBookmarkBase64)
        await TrackRegistry.shared.upsertTrack(
            id: trackId,
            fileName: fileName,
            folderId: destinationFolderId,
            rootFolderId: entry.rootFolderId
        )

        // 10. Persist
        await BookmarksRegistry.shared.persist()
        await TrackRegistry.shared.persist()

        print("💾 moveTrack: реестры обновлены для трека \(trackId)")
    }

    // MARK: - Переименовываем файл
  
    /// - Parameters:
    ///   - trackId: ID трека.
    ///   - newFileName: новое имя файла (желательно с расширением).
    ///   - playerManager: актуальный экземпляр PlayerManager.
    func renameTrack(
        id trackId: UUID,
        to newFileName: String,
        using playerManager: PlayerManager
    ) async throws {
        // 1. Проверяем, не занят ли трек плеером
        if playerManager.isBusy(trackId) {
            print("🚫 Нельзя переименовать трек \(trackId) — он сейчас воспроизводится.")
            throw LibraryFileError.trackIsPlaying
        }

        // 2. Берём метаданные трека
        guard let entry = await TrackRegistry.shared.entry(for: trackId) else {
            print("❌ TrackRegistry: трек \(trackId) не найден")
            throw LibraryFileError.trackNotFound
        }

        // 3. URL файла через bookmark трека
        guard let sourceURL = await BookmarkResolver.url(forTrack: trackId) else {
            print("❌ Не удалось восстановить URL файла для трека \(trackId)")
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
            print("⚠️ В папке уже есть файл \(newFileName)")
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
            print("❌ Ошибка переименования файла: \(error)")
            throw LibraryFileError.moveFailed(underlying: error)
        }

        // 5. Новый bookmark для нового имени
        guard let newBookmarkBase64 = BookmarkResolver.makeBookmarkBase64(for: destinationURL) else {
            print("❌ Не удалось создать bookmark для нового имени файла")
            throw LibraryFileError.bookmarkCreationFailed
        }

        // 6. Обновляем реестры
        await BookmarksRegistry.shared.upsertTrackBookmark(id: trackId, base64: newBookmarkBase64)
        await TrackRegistry.shared.upsertTrack(
            id: trackId,
            fileName: newFileName,
            folderId: entry.folderId,
            rootFolderId: entry.rootFolderId
        )

        await BookmarksRegistry.shared.persist()
        await TrackRegistry.shared.persist()

        print("💾 renameTrack: реестры обновлены для трека \(trackId)")
    }
}
