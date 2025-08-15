//
//  MusicLibraryManager.swift
//  TrackList
//
//  Управляет доступом к прикреплённым папкам фонотеки, сканированием аудиофайлов и восстановлением доступа
//
//  Created by Pavel Fomin on 22.06.2025.
//

import Foundation
import UniformTypeIdentifiers
import Combine
import AVFoundation
import UIKit

final class MusicLibraryManager: ObservableObject {
    static let shared = MusicLibraryManager()  /// Синглтон
    
    init() {Task { @MainActor in await self.restoreAccess() }  /// Восстанавливает доступ к сохранённым папкам
        
    }
    
    private let cacheQueue = DispatchQueue(label: "importedTrackCache.queue") /// Очередь для потокобезопасного доступа к importedTrackCache
    
    
// MARK: - Bookmark и кэш
    
    private var appDirectory: URL? {FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first}  /// Абсолютный путь к директории приложения /Documents
    private var importedTrackCache: [String: ImportedTrack] = [:]    /// Кэш импортированных треков по абсолютному пути (используется при повторном сканировании)
    @Published var pendingDeleteURL: URL? = nil  /// URL папки, ожидающей удаление
    @Published var isAccessReady = false
    /// Путь к JSON-файлу, в котором сохраняются bookmarkData всех прикреплённых папок
    private static var bookmarksFileURL: URL {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return folder.appendingPathComponent("music_bookmarks.json")}
    
    
// MARK: - Сохранение bookmarkData в файл
    
    /// Сохраняет новый bookmark в общий bookmarks.json, избегая дублирования
    func saveBookmarkDataToFile(_ newData: Data) {
        let url = Self.bookmarksFileURL
        
        var existingDataArray: [Data] = []
        
        // Читаем существующие bookmarks
        if let data = try? Data(contentsOf: url),
           let array = try? JSONDecoder().decode([Data].self, from: data) {
            existingDataArray = array
        }
        
        // Добавим только если такого bookmark ещё нет
        if !existingDataArray.contains(newData) {
            existingDataArray.append(newData)
        }
        
        // Перезаписываем файл
        do {
            let encoder = makePrettyJSONEncoder()
            let newData = try encoder.encode(existingDataArray)
            try newData.write(to: url)
            print("💾 Сохранили \(existingDataArray.count) папок в bookmarks.json")
        } catch {
            print("❌ Не удалось сохранить bookmarkData: \(error)")
        }
    }
    
    
// MARK: - Публичные состояния
    
    @Published var folderURL: URL?                       /// Текущая активная папка (если одна)
    @Published var tracks: [URL] = []                    /// Все найденные треки (плоский список)
    @Published var rootFolder: LibraryFolder?            /// Корневая папка со вложенной структурой
    @Published var attachedFolders: [LibraryFolder] = [] /// Прикреплённые папки с поддеревьями
    
    
// MARK: -  Рекурсивный обход папки с вложенностью
    
    /// Строит дерево LibraryFolder на основе структуры вложенных директорий
    /// - Parameter folderURL: Абсолютный путь к папке
    /// - Returns: LibraryFolder со списком аудиофайлов и подпапок
    func buildFolderTree(from folderURL: URL) -> LibraryFolder {
        let fileManager = FileManager.default
        let folderName = folderURL.lastPathComponent
        
        var subfolders: [LibraryFolder] = []
        var audioFiles: [URL] = []
        
        if let contents = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for item in contents {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    
                    // Рекурсивно сканируем подпапку
                    let subfolder = buildFolderTree(from: item)
                    subfolders.append(subfolder)
                } else {
                    // Сохраняем только поддерживаемые форматы
                    let ext = item.pathExtension.lowercased()
                    if ["mp3", "flac", "wav", "aiff", "aac", "m4a", "ogg"].contains(ext) {
                        audioFiles.append(item)
                    }
                }
            }
        }
        
        return LibraryFolder(name: folderName, url: folderURL, subfolders: subfolders, audioFiles: audioFiles)
    }
    
    
// MARK: - Сохраняет bookmark
    
    /// Сохраняет bookmark для выбранной папки и строит по ней дерево
    func saveBookmark(for url: URL) {
        if url.startAccessingSecurityScopedResource() {
            do {
                let bookmarkData = try url.bookmarkData(
                    options: [],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                saveBookmarkDataToFile(bookmarkData)
                
                DispatchQueue.main.async {
                    self.folderURL = url
                    self.tracks = [] /// очищаем список треков, если он использовался
                }
            } catch {
                print("❌ Не удалось создать bookmarkData: \(error)")
            }
        } else {
            print("❌ Не удалось начать доступ к папке")
        }
    }
    
    
// MARK: - Загрузка массива bookmarkData из файла
    
    /// Загружает сохранённый массив bookmarkData из JSON
    private func loadBookmarkDataFromFile() -> [Data]? {
        let url = Self.bookmarksFileURL
        
        guard let data = try? Data(contentsOf: url) else {
            print("⚠️ Файл закладок не найден: \(url.lastPathComponent)")
            return nil
        }
        
        do {
            let array = try JSONDecoder().decode([Data].self, from: data)
            return array
        } catch {
            print("❌ Не удалось декодировать bookmarkData: \(error)")
            return nil
        }
    }
    
    
// MARK: - Загрузка подпапок для папки (ленивая)
    
    func loadSubfolders(for folderURL: URL) -> [LibraryFolder] {
        let fileManager = FileManager.default
        var result: [LibraryFolder] = []
        
        if let contents = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for item in contents {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    result.append(liteFolder(from: item))
                }
            }
        }
        return result
    }
    
    
// MARK: - Хелпер
    
    private func liteFolder(from url: URL) -> LibraryFolder {
        LibraryFolder(
            name: url.lastPathComponent,
            url: url,
            subfolders: [],   // подпапки — лениво
            audioFiles: []    // файлы — лениво
        )
    }
    
    
// MARK: - Восстанавливает доступ к ранее прикреплённым папкам
    
    /// Восстанавливает доступ к прикреплённым папкам при запуске
    @MainActor
    func restoreAccess() async {
        guard let dataArray = loadBookmarkDataFromFile() else {
            print("ℹ️ Bookmarks не найдены")
            return
        }
        
        var urls: [URL] = []
        
        for data in dataArray {
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: data,
                    options: [.withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                if url.startAccessingSecurityScopedResource() {
                    print("✅ Доступ к папке восстановлен: \(url.lastPathComponent)")
                    urls.append(url)
                } else {
                    print("❌ Не удалось начать доступ к папке: \(url.lastPathComponent)")
                }
            } catch {
                print("❌ Ошибка восстановления доступа: \(error)")
            }
        }
        
        await MainActor.run {
            self.attachedFolders = urls.map { self.liteFolder(from: $0) }
            self.isAccessReady = true
        }
    }
    
    
// MARK: - Удаление bookmarkData по URL
    
    /// Удаляет сохранённый bookmark и обновляет список папок в UI
    func removeBookmark(for folderURL: URL) {
        let url = Self.bookmarksFileURL
        
        guard let data = try? Data(contentsOf: url),
              var existing = try? JSONDecoder().decode([Data].self, from: data) else {
            print("⚠️ Не удалось загрузить bookmarkData для удаления")
            return
        }
        
        // Удаляем совпадающий bookmark по url
        existing.removeAll { data in
            var isStale = false
            if let resolved = try? URL(
                resolvingBookmarkData: data,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                return resolved == folderURL
            }
            return false
        }
        
        // Сохраняем обновлённый список
        do {
            let newData = try JSONEncoder().encode(existing)
            try newData.write(to: url)
            print("🗑️ Удалили папку из bookmarks: \(folderURL.lastPathComponent)")
        } catch {
            print("❌ Не удалось сохранить обновлённый список bookmarks")
        }
        
        // Обновим UI и пересчитаем список папок
        Task { @MainActor in
            await self.restoreAccess()
            NotificationCenter.default.post(name: .attachedFoldersDidChange, object: nil)
            self.purgeInvalidBookmarks()
        }
    }
    
// MARK: - Удаляет физическую папку и bookmark
    
    func removeFolderAndBookmark(url: URL) {
        print("📂 Начинаем удаление папки и закладки: \(url.path)")

        // 1. Удаляем папку с диска
        switch LibraryFileManager.shared.deleteItem(at: url) {
        case .success:
            print("🗑️ Папка удалена физически: \(url.lastPathComponent)")
        case .failure(let error):
            print("❌ Ошибка при удалении папки: \(error.localizedDescription)")
            return
        }

        // 2. Удаляем из закладок
        removeBookmark(for: url)
    }
    
// MARK: - Очищает несуществующие записи из bookmarks.json
    
    func purgeInvalidBookmarks() {
        let fileURL = Self.bookmarksFileURL
        
        guard let data = try? Data(contentsOf: fileURL),
              let existing = try? JSONDecoder().decode([Data].self, from: data) else {
            print("⚠️ Не удалось загрузить bookmarks.json для очистки")
            return
        }
        
        var valid: [Data] = []
        
        for bookmark in existing {
            var isStale = false
            if let resolved = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale),
               FileManager.default.fileExists(atPath: resolved.path) {
                valid.append(bookmark)
            } else {
                print("🧹 Удаляем битую закладку из bookmarks.json")
            }
        }
        
        do {
            let cleanedData = try JSONEncoder().encode(valid)
            try cleanedData.write(to: fileURL)
            print("✅ Очистка завершена: \(valid.count) закладок осталось")
        } catch {
            print("❌ Не удалось сохранить очищенный bookmarks.json: \(error)")
        }
    }
    
// MARK: - Перемещение bookmark по новому пути
    
    /// Обновляет путь в bookmarks.json при переименовании или перемещении папки
    func moveBookmark(from oldURL: URL, to newURL: URL) {
        let fileURL = Self.bookmarksFileURL
        
        guard let data = try? Data(contentsOf: fileURL),
              var existing = try? JSONDecoder().decode([Data].self, from: data) else {
            print("⚠️ Не удалось загрузить bookmarkData для перемещения")
            return
        }
        
        // Найдём старую запись
        if let index = existing.firstIndex(where: {
            var isStale = false
            if let resolved = try? URL(
                resolvingBookmarkData: $0,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                return resolved == oldURL
            }
            return false
        }) {
            // Создаём bookmarkData для нового URL
            if let newData = try? newURL.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                existing[index] = newData
                
                // Сохраняем обновлённый файл
                if let newData = try? newURL.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                    existing[index] = newData
                    
                    // Сохраняем обновлённый файл
                    if let newFileData = try? JSONEncoder().encode(existing) {
                        try? newFileData.write(to: fileURL)
                        print("🔁 Обновили bookmark после перемещения: \(oldURL.lastPathComponent) → \(newURL.lastPathComponent)")
                        
                        Task { @MainActor in
                            await self.restoreAccess()
                        }
                    }
                }
            }
        }
    }
    
    
// MARK: - Генерация LibraryTrack объектов для отображения
    
    /// Асинхронно преобразует массив URL-ов в массив LibraryTrack, включая парсинг тегов и создание bookmark
    func generateLibraryTracks(from urls: [URL]) async -> [LibraryTrack] {
        await withTaskGroup(of: LibraryTrack?.self) { group in
            for url in urls {
                group.addTask { [self] in
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer {
                        if accessed { url.stopAccessingSecurityScopedResource() }
                    }
                    
                    // Дата создания или модификации
                    let resourceValues = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
                    let addedDate = resourceValues?.creationDate ?? resourceValues?.contentModificationDate ?? Date()
                    
                    // Парсим теги (TagLib)
                    let metadata = try? await MetadataParser.parseMetadata(from: url)
                    
                    // Bookmark для доступа к файлу
                    let bookmarkData = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                    let bookmarkBase64 = bookmarkData?.base64EncodedString() ?? ""
                    
                    // Проверка кэша
                    let imported: ImportedTrack
                    let filePath = url.path
                    
                    let cached: ImportedTrack? = cacheQueue.sync {
                        importedTrackCache[filePath]
                    }
                    
                    if let cached {
                        imported = cached
                    } else {
                        let newTrack = ImportedTrack(
                            id: UUID(uuidString: url.lastPathComponent) ?? UUID(),
                            fileName: url.lastPathComponent,
                            filePath: filePath,
                            orderPrefix: "",
                            title: metadata?.title,
                            artist: metadata?.artist,
                            album: metadata?.album,
                            duration: metadata?.duration ?? 0,
                            bookmarkBase64: bookmarkBase64
                        )
                        cacheQueue.sync {
                            importedTrackCache[filePath] = newTrack
                        }
                        imported = newTrack
                    }
                    
                    let resolvedURL = SecurityScopedBookmarkHelper.resolveURL(from: bookmarkBase64) ?? url
                    let isAvailable = FileManager.default.fileExists(atPath: resolvedURL.path)
                    
                    return LibraryTrack(
                        url: url,
                        resolvedURL: resolvedURL,
                        isAvailable: isAvailable,
                        bookmarkBase64: bookmarkBase64,
                        title: metadata?.title ?? url.deletingPathExtension().lastPathComponent,
                        artist: metadata?.artist,
                        duration: metadata?.duration ?? 0,
                        artwork: nil,
                        addedDate: addedDate,
                        original: imported
                    )
                }
            }
            
            var results: [LibraryTrack] = []
            for await result in group {
                if let track = result {
                    results.append(track)
                }
            }
            return results
        }
    }
    
// MARK: - Обновление списка прикреплённых папок

    @MainActor
    func refresh() async {await restoreAccess()}
    
    
// MARK: - Обновление содержимого одной папки

    /// Перестраивает содержимое указанной папки (с обновлением подпапок и треков)
    @MainActor
    func refresh(folder: LibraryFolder) -> LibraryFolder {
        return buildFolderTree(from: folder.url)}
}
