//
//  MusicLibraryManager.swift
//  TrackList
//
//  Created by Pavel Fomin on 22.06.2025.
//

import Foundation
import UniformTypeIdentifiers
import Combine

final class MusicLibraryManager: ObservableObject {
    static let shared = MusicLibraryManager()
    
    private let bookmarkKey = "musicLibraryBookmark"
    private var isAccessing = false
    
    // Пути к файлам
    private var appDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    private var bookmarkFileURL: URL? {
        appDirectory?.appendingPathComponent("music_library_bookmark.json")
    }
    
    
    // Сохранение bookmarkData в файл
    private func saveBookmarkDataToFile(_ data: Data) {
        guard let url = bookmarkFileURL else {
            print("❌ Не удалось получить путь к файлу bookmark")
            return
        }
        
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
            print("💾 BookmarkData сохранён в файл")
        } catch {
            print("❌ Ошибка при сохранении bookmarkData в файл: \(error)")
        }
    }
    
    private func loadBookmarkDataFromFile() -> Data? {
        guard let url = bookmarkFileURL else { return nil }
        return try? Data(contentsOf: url)
    }
    
    init() {
        print("🎬 MusicLibraryManager init — восстанавливаем доступ")
    }
    
    @Published var folderURL: URL?
    @Published var tracks: [URL] = []
    
    
    // Сканирование папки
    func scanMusicFolder() {
        guard let folderURL else {
            print("⚠️ Папка не выбрана")
            DispatchQueue.main.async {
                self.tracks = []
            }
            return
        }
        
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            
            let supportedExtensions = ["mp3", "flac", "wav", "aiff", "aac", "m4a", "ogg"]
            let audioFiles = contents.filter { url in
                let ext = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return supportedExtensions.contains(ext)
            }
            
            DispatchQueue.main.async {
                self.tracks = audioFiles
            }
            
            print("🎵 Найдено треков в папке: \(audioFiles.count)")
        } catch {
            print("❌ Ошибка при сканировании папки: \(error)")
            DispatchQueue.main.async {
                self.tracks = []
            }
        }
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
                
                // ✅ Всё внутри одного main-потока
                DispatchQueue.main.async {
                    self.folderURL = url
                    self.tracks = [] // Очистка треков
                    self.scanMusicFolder() // Скан новой папки
                }
            } catch {
                print("❌ Не удалось создать bookmarkData: \(error)")
            }
        } else {
            print("❌ Не удалось начать доступ к папке")
        }
    }
    
    // Восстанавливает bookmark при запуске
    func restoreAccess() {
        guard let data = loadBookmarkDataFromFile(), !isAccessing else {
            print("ℹ️ Bookmark-файл не найден или уже получен доступ")
            return
        }

        var isStale = false

        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if url.startAccessingSecurityScopedResource() {
                isAccessing = true // 👈 Отмечаем, что доступ получен
                DispatchQueue.main.async {
                    self.folderURL = url
                    print("✅ Доступ к папке фонотеки восстановлен: \(url.lastPathComponent)")
                    self.scanMusicFolder()
                }
            } else {
                print("❌ Не удалось получить доступ к папке")
            }
        } catch {
            print("❌ Ошибка при восстановлении bookmark: \(error)")
        }
    }
}
