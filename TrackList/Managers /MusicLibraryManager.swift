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
    
    /// Синглтон
    static let shared = MusicLibraryManager()
    
    /// При инициализации сразу восстанавливает доступ к сохранённым папкам
    init() {
        restoreAccess()
    }
    
    /// Очередь для потокобезопасного доступа к importedTrackCache
    private let cacheQueue = DispatchQueue(label: "importedTrackCache.queue")
    
    
    // MARK: - Bookmark и кэш
    
    /// Ключ для UserDefaults (не используется, остался от старой реализации?)
    private let bookmarkKey = "musicLibraryBookmark"
    
    /// Флаг, чтобы не дублировать startAccessing
    private var isAccessing = false
    
    /// Абсолютный путь к директории приложения /Documents
    private var appDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    /// Кэш импортированных треков по абсолютному пути (используется при повторном сканировании)
    private var importedTrackCache: [String: ImportedTrack] = [:]
    
    /// Путь к JSON-файлу, в котором сохраняются bookmarkData всех прикреплённых папок
    private static var bookmarksFileURL: URL {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return folder.appendingPathComponent("music_bookmarks.json")
    }
    
    
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
                    self.rootFolder = self.buildFolderTree(from: url)
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
    
    
// MARK: - Восстанавливает доступ к ранее прикреплённым папкам

    /// Восстанавливает доступ к прикреплённым папкам при запуске
    func restoreAccess() {
        
        // Очистим предыдущие данные
            attachedFolders = []
            tracks = []
        
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
                    options: [.withoutUI], ///убрали .withSecurityScope — он не работает на iOS
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
        
        // Создаём дерево для каждой папки
        for url in urls {
            DispatchQueue.main.async {
                let newFolder = self.buildFolderTree(from: url)
                self.attachedFolders.append(newFolder)
                self.tracks.append(contentsOf: newFolder.audioFiles)
            }
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
        DispatchQueue.main.async {
            self.attachedFolders.removeAll { $0.url == folderURL }
            self.tracks = self.attachedFolders.flatMap { $0.audioFiles }
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
                        if accessed {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    // Получаем длительность через AVAsset
                    let asset = AVURLAsset(url: url)
                    let duration = try? await asset.load(.duration)
                    let durationSeconds = duration.map(CMTimeGetSeconds)
                    
                    // Дата создания или модификации
                    let resourceValues = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
                    let addedDate = resourceValues?.creationDate ?? resourceValues?.contentModificationDate ?? Date()
                    
                    // Парсим теги
                    let metadata = try? await MetadataParser.parseMetadata(from: url)
                    
                    // Парсим обложку
                    let artworkBase64 = metadata?.artworkData?.base64EncodedString()

                    
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
                            album: nil,
                            duration: metadata?.duration ?? durationSeconds ?? 0,
                            bookmarkBase64: bookmarkBase64,
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
                        title: metadata?.title,
                        artist: metadata?.artist,
                        duration: metadata?.duration ?? durationSeconds ?? 0,
                        artwork: metadata?.artworkData
                            .flatMap { UIImage(data: $0) }
                            .map { normalize($0) },
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
