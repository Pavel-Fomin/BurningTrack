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
    
    init() {
        // Восстановление доступа выполняем в фоне, чтобы не блокировать main thread
        Task.detached(priority: .background) { [weak self] in
            await self?.restoreAccessAsync()
        }
    }
    
    private let cacheQueue = DispatchQueue(label: "importedTrackCache.queue") /// Очередь для потокобезопасного доступа к importedTrackCache
    
    
    // MARK: - Bookmark и кэш
    
    private let bookmarkKey = "musicLibraryBookmark"  /// Ключ для UserDefaults (не используется, остался от старой реализации?)
    private var isAccessing = false                   /// Флаг, чтобы не дублировать startAccessing
    private var appDirectory: URL? {FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first}  /// Абсолютный путь к директории приложения /Documents
    private var importedTrackCache: [String: ImportedTrack] = [:]    /// Кэш импортированных треков по абсолютному пути (используется при повторном сканировании)
    
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
    
    @Published private(set) var isAccessRestored = false /// Флаг готовности после restoreAccessAsync()
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
    
    // MARK: - Хелпер
    
    func liteFolder(from url: URL) -> LibraryFolder {
        LibraryFolder(
            name: url.lastPathComponent,
            url: url,
            subfolders: [],   // подпапки — лениво
            audioFiles: []    // файлы — лениво
        )
    }
    
    
    // MARK: - Восстанавливает доступ к ранее прикреплённым папкам
    
    /// Восстанавливает доступ к прикреплённым папкам при запуске
    func restoreAccessAsync() async {
        print("🔁 Начало восстановления доступа")
        guard let dataArray = loadBookmarkDataFromFile(), !dataArray.isEmpty else {
            print("ℹ️ Bookmarks не найдены")
            await MainActor.run { self.attachedFolders = [] }
            return
        }
        
        var urls: [URL] = []
        urls.reserveCapacity(dataArray.count)
        
        for data in dataArray {
            do {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: data,
                    options: [.withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                if isStale {
                    if let newData = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                        replaceBookmarkData(old: data, with: newData)
                        print("♻️ Обновили протухший bookmark для: \(url.lastPathComponent)")
                    }
                }
                
                if url.startAccessingSecurityScopedResource() {
                    urls.append(url)
                    print("✅ Доступ к папке восстановлен: \(url.lastPathComponent)")
                } else {
                    print("⚠️ Не удалось начать доступ к папке: \(url.lastPathComponent)")
                }
            } catch {
                print("❌ Ошибка восстановления доступа: \(error)")
            }
        }
        
        // создаём независимую константу — это снимает предупреждение Swift 6
        let resolvedURLs = urls.map { $0 }
        
        await MainActor.run {
            self.attachedFolders = resolvedURLs.map { self.buildFolderTree(from: $0) }
        }
        await MainActor.run {
            self.isAccessRestored = true
        }
        print("✅ Завершено восстановление доступа")
    }
    
    
// MARK: - Ожидание восстановления доступа
    func waitForAccess() async {
        for await value in $isAccessRestored.values {
            if value { break } // ждем первое true и выходим
        }
    }
    
    
// MARK: - Навигация и выделение трека
    @MainActor
    func openFolder(at folderURL: URL, highlight trackURL: URL) async {
        // Проверяем, что папка действительно прикреплена
        guard let folder = attachedFolders.first(where: { $0.url == folderURL }) else {
            print("⚠️ Папка не найдена среди прикреплённых: \(folderURL.lastPathComponent)")
            return
        }
        // Обновляем список в UI (на случай если это текущая папка)
        if let index = attachedFolders.firstIndex(where: { $0.url == folderURL }) {
            attachedFolders[index] = folder
        }
        // Отправляем событие напрямую через NavigationCoordinator
        NavigationCoordinator.shared.pendingReveal = trackURL
    }
    
    
// MARK: - Заменяет старую запись bookmarkData на новую в music_bookmarks.json
    
    private func replaceBookmarkData(old: Data, with new: Data) {
        let url = Self.bookmarksFileURL
        guard
            let data = try? Data(contentsOf: url),
            var array = try? JSONDecoder().decode([Data].self, from: data)
        else { return }
        
        if let idx = array.firstIndex(of: old) { array[idx] = new }
        else if !array.contains(new) { array.append(new) }
        
        if let encoded = try? JSONEncoder().encode(array) {
            try? encoded.write(to: url)
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
            
            // Обновим список в UI
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.attachedFolders.removeAll { $0.url == folderURL }
                self.tracks = self.attachedFolders.flatMap { $0.audioFiles }
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
    }
