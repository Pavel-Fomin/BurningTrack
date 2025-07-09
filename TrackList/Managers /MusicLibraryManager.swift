//
//  MusicLibraryManager.swift
//  TrackList
//
//  Created by Pavel Fomin on 22.06.2025.
//

import Foundation
import UniformTypeIdentifiers
import Combine
import AVFoundation
import UIKit


final class MusicLibraryManager: ObservableObject {
    static let shared = MusicLibraryManager()
    
    init() {
        restoreAccess()
    }
    
    private let bookmarkKey = "musicLibraryBookmark"
    private var isAccessing = false
    
    // Пути к файлам
    private var appDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    
    // MARK: - Путь к файлу bookmarks
    
    private static var bookmarksFileURL: URL {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return folder.appendingPathComponent("music_bookmarks.json")
    }
    
    
    // Сохранение bookmarkData в файл
    func saveBookmarkDataToFile(_ newData: Data) {
        let url = Self.bookmarksFileURL
        
        var existingDataArray: [Data] = []
        
        if let data = try? Data(contentsOf: url),
           let array = try? JSONDecoder().decode([Data].self, from: data) {
            existingDataArray = array
        }
        
        // Добавим только если такой папки ещё нет
        if !existingDataArray.contains(newData) {
            existingDataArray.append(newData)
        }
        
        do {
            let encoded = try JSONEncoder().encode(existingDataArray)
            try encoded.write(to: url)
            print("💾 Сохранили \(existingDataArray.count) папок в bookmarks.json")
        } catch {
            print("❌ Не удалось сохранить bookmarkData: \(error)")
        }
    }
    
    @Published var folderURL: URL?
    @Published var tracks: [URL] = []
    @Published var rootFolder: LibraryFolder?
    @Published var attachedFolders: [LibraryFolder] = []
    
    // Рекурсивный обход папки с вложенностью
    func buildFolderTree(from folderURL: URL) -> LibraryFolder {
        let fileManager = FileManager.default
        let folderName = folderURL.lastPathComponent
        
        var subfolders: [LibraryFolder] = []
        var audioFiles: [URL] = []
        
        if let contents = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for item in contents {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    let subfolder = buildFolderTree(from: item)
                    subfolders.append(subfolder)
                } else {
                    let ext = item.pathExtension.lowercased()
                    if ["mp3", "flac", "wav", "aiff", "aac", "m4a", "ogg"].contains(ext) {
                        audioFiles.append(item)
                    }
                }
            }
        }
        
        return LibraryFolder(name: folderName, url: folderURL, subfolders: subfolders, audioFiles: audioFiles)
    }
    
    
    // Сохраняет bookmark
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
                    self.tracks = [] // опционально: сброс списка
                    self.rootFolder = self.buildFolderTree(from: url)
                }
            } catch {
                print("❌ Не удалось создать bookmarkData: \(error)")
            }
        } else {
            print("❌ Не удалось начать доступ к папке")
        }
    }
    
    // Загрузка массива bookmarkData из файла
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
    
    // Восстанавливает bookmark при запуске
    // Восстанавливает доступ ко всем сохранённым папкам
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
                    options: [.withoutUI], // ⚠️ убрали .withSecurityScope — он не работает на iOS
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
        
        for url in urls {
            DispatchQueue.main.async {
                let newFolder = self.buildFolderTree(from: url)
                self.attachedFolders.append(newFolder)
                self.tracks.append(contentsOf: newFolder.audioFiles)
            }
        }
    }
    
    // Удаляет bookmarkData по заданному URL
    func removeBookmark(for folderURL: URL) {
        let url = Self.bookmarksFileURL

        guard let data = try? Data(contentsOf: url),
              var existing = try? JSONDecoder().decode([Data].self, from: data) else {
            print("⚠️ Не удалось загрузить bookmarkData для удаления")
            return
        }

        // Удалим все совпадающие
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
    
    func generateLibraryTracks(from urls: [URL]) async -> [LibraryTrack] {
        await withTaskGroup(of: LibraryTrack?.self) { group in
            for url in urls {
                group.addTask {
                    let asset = AVURLAsset(url: url)
                    let duration = try? await asset.load(.duration)
                    let durationSeconds = duration.map(CMTimeGetSeconds)

                    let resourceValues = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
                    let addedDate = resourceValues?.creationDate ?? resourceValues?.contentModificationDate ?? Date()

                    let metadata = try? await MetadataParser.parseMetadata(from: url)

                    let bookmarkData = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                    let bookmarkBase64 = bookmarkData?.base64EncodedString() ?? ""

                    let imported = ImportedTrack(
                        id: UUID(),
                        fileName: url.lastPathComponent,
                        filePath: url.path,
                        orderPrefix: "",
                        title: metadata?.title,
                        artist: metadata?.artist,
                        album: nil,
                        duration: metadata?.duration ?? durationSeconds ?? 0,
                        artworkBase64: nil,
                        bookmarkBase64: bookmarkBase64,
                        artworkId: nil,
                    )

                    return LibraryTrack(
                        url: url,
                        bookmarkBase64: bookmarkBase64,
                        title: metadata?.title,
                        artist: metadata?.artist,
                        duration: metadata?.duration ?? durationSeconds ?? 0,
                        artwork: metadata?.artworkData.flatMap { UIImage(data: $0) },
                        addedDate: addedDate,
                        original: imported // 👈 обязательный аргумент
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
