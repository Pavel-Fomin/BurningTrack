//
//  MusicLibraryManager.swift
//  TrackList
//
//  Управляет доступом к прикреплённым папкам фонотеки, сканированием аудиофайлов и восстановлением доступа
//
//  Created by Pavel Fomin on 22.06.2025.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Combine
import AVFoundation
import UIKit

@MainActor
final class MusicLibraryManager: ObservableObject {
    
    static let shared = MusicLibraryManager()
    
    // MARK: - Published состояния
    
    @Published private(set) var isAccessRestored = false
    @Published var attachedFolders: [LibraryFolder] = []
    @Published var tracks: [URL] = []
    @Published var isInitialFoldersLoadFinished: Bool = false
    
    // MARK: - Инициализация
    
    init() {
        Task.detached(priority: .background) { [weak self] in
            await self?.restoreAccessAsync()
        }
    }
    
    // MARK: - Ленивая модель папки
    
    func liteFolder(from url: URL) -> LibraryFolder {
        LibraryFolder(
            name: url.lastPathComponent,
            url: url,
            subfolders: [],
            audioFiles: []
        )
    }
    
    // MARK: - Полное дерево папки
    
    func buildFolderTree(from folderURL: URL) -> LibraryFolder {
        let fm = FileManager.default
        let name = folderURL.lastPathComponent
        
        var subfolders: [LibraryFolder] = []
        var audioFiles: [URL] = []
        
        if let contents = try? fm.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for item in contents {
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                    subfolders.append(buildFolderTree(from: item))
                } else {
                    let ext = item.pathExtension.lowercased()
                    if ["mp3", "flac", "wav", "aiff", "aac", "m4a", "ogg"].contains(ext) {
                        audioFiles.append(item)
                    }
                }
            }
        }
        
        return LibraryFolder(
            name: name,
            url: folderURL,
            subfolders: subfolders,
            audioFiles: audioFiles
        )
    }
    
    
    func loadSubfolders(for folderURL: URL) -> [LibraryFolder] {
        var subfolders: [LibraryFolder] = []
        
        let accessed = folderURL.startAccessingSecurityScopedResource()
        defer { if accessed { folderURL.stopAccessingSecurityScopedResource() } }
        
        do {
            let fm = FileManager.default
            let items = try fm.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            for item in items {
                let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDir {
                    let folder = liteFolder(from: item)
                    subfolders.append(folder)
                }
                
            }
        } catch {
            print("❌ loadSubfolders error:", error)
        }
        
        return subfolders
    }
    
    
    
    // MARK: - Сохраняем bookmark выбранной папки и регистрируем её
    
    func saveBookmark(for url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            print("❌ Не удалось начать доступ к папке")
            return
        }
        
        Task {
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let bookmarkData = try url.bookmarkData()
                let bookmarkBase64 = bookmarkData.base64EncodedString()
                
                let folderId = url.libraryFolderId
                let name = url.lastPathComponent
                let path = url.path
                
                // 1) Регистрируем папку в TrackRegistry
                await TrackRegistry.shared.registerFolder(
                    folderId: folderId,
                    name: name,
                    path: path,
                    bookmarkBase64: bookmarkBase64
                )
                
                // 2) Индексируем все аудиофайлы в этой папке (рекурсивно)
                let fm = FileManager.default
                var stack: [URL] = [url]
                
                while let current = stack.popLast() {
                    guard let items = try? fm.contentsOfDirectory(
                        at: current,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles]
                    ) else { continue }
                    
                    for item in items {
                        let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                        
                        if isDir {
                            // Папка — добавляем в стек для дальнейшего обхода
                            stack.append(item)
                        } else {
                            // Файл — проверяем расширение
                            let ext = item.pathExtension.lowercased()
                            let allowed = ["mp3", "flac", "wav", "aiff", "aac", "m4a", "ogg"]
                            
                            guard allowed.contains(ext) else { continue }
                            
                            // Генерируем/получаем стабильный trackId
                            let trackId = await TrackRegistry.shared.trackId(for: item)
                            
                            // Создаём bookmark для конкретного файла
                            guard let fileBookmark = try? item.bookmarkData() else { continue }
                            let fileBookmarkBase64 = fileBookmark.base64EncodedString()
                            
                            // Регистрируем трек в реестре
                            await TrackRegistry.shared.register(
                                trackId: trackId,
                                bookmarkBase64: fileBookmarkBase64,
                                folderId: folderId,
                                fileName: item.lastPathComponent
                            )
                        }
                    }
                }
                
                // 3) Обновляем UI-состояние
                await MainActor.run {
                    if self.attachedFolders.contains(where: { $0.url == url }) == false {
                        self.attachedFolders.append(self.liteFolder(from: url))
                    }
                }
                
                print("📁 Папка добавлена и проиндексирована: \(name)")
                
            } catch {
                print("❌ Не удалось создать bookmarkData: \(error)")
            }
        }
    }
    
    // MARK: - Удаление прикреплённой папки
    
    func removeBookmark(for url: URL) {
        Task {
            let folderId = url.libraryFolderId
            
            // 1) Удаляем запись папки и все её треки из TrackRegistry
            await TrackRegistry.shared.removeFolder(folderId: folderId)
            
            // 2) Обновляем UI-состояние
            await MainActor.run {
                self.attachedFolders.removeAll { $0.url == url }
            }
            
            print("📁 Папка откреплена:", url.lastPathComponent)
        }
    }
    
    // MARK: - Поиск папки по ID

    func folder(for folderId: UUID) -> LibraryFolder? {
        func search(in folders: [LibraryFolder]) -> LibraryFolder? {
            for f in folders {
                if f.url.libraryFolderId == folderId {
                    return f
                }
                if let found = search(in: f.subfolders) {
                    return found
                }
            }
            return nil
        }

        return search(in: attachedFolders)
    }
    
    // MARK: - Восстановление прикреплённых папок через TrackRegistry
    
    func restoreAccessAsync() async {
        print("🔁 Восстановление доступа к папкам…")
        
        await TrackRegistry.shared.load()
        
        let folders = await TrackRegistry.shared.foldersList()
        
        if folders.isEmpty {
            print("ℹ️ Нет сохранённых папок")
            await MainActor.run {
                self.isAccessRestored = true
                self.isInitialFoldersLoadFinished = true
            }
            return
        }
        
        var resolvedFolders: [LibraryFolder] = []
        
        for folder in folders {
            guard
                let data = Data(base64Encoded: folder.bookmarkBase64)
            else { continue }
            
            var stale = false
            
            do {
                let url = try URL(
                    resolvingBookmarkData: data,
                    options: [.withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale
                )
                
                if stale {
                    print("⚠️ Bookmark устарел: \(folder.name)")
                }
                
                if url.startAccessingSecurityScopedResource() {
                    let tree = buildFolderTree(from: url)
                    resolvedFolders.append(tree)
                    print("✅ Доступ к папке: \(folder.name)")
                } else {
                    print("⚠️ Ошибка доступа к папке: \(folder.name)")
                }
                
            } catch {
                print("❌ Ошибка восстановления bookmark: \(error)")
            }
        }
        
        await MainActor.run {
            self.attachedFolders = resolvedFolders
            self.isAccessRestored = true
            self.isInitialFoldersLoadFinished = true
        }
        
        print("✅ Восстановление доступа завершено")
        
        
        // MARK: - Асинхронная генерация LibraryTrack
        
        func generateLibraryTracks(from urls: [URL], folderId: UUID) async -> [LibraryTrack] {
            await withTaskGroup(of: LibraryTrack?.self) { group in
                for url in urls {
                    group.addTask {
                        
                        let trackId = await TrackRegistry.shared.trackId(for: url)
                        
                        let accessed = url.startAccessingSecurityScopedResource()
                        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                        
                        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
                        let addedDate = values?.creationDate ??
                        values?.contentModificationDate ??
                        Date()
                        
                        // Создаём bookmark для конкретного файла
                        let bookmarkData = (try? url.bookmarkData()) ?? Data()
                        let bookmarkBase64 = bookmarkData.base64EncodedString()
                        
                        // Регистрация трека
                        await TrackRegistry.shared.register(
                            trackId: trackId,
                            bookmarkBase64: bookmarkBase64,
                            folderId: folderId,
                            fileName: url.lastPathComponent
                        )
                        
                        return LibraryTrack(
                            id: trackId,
                            fileURL: url,
                            title: nil,
                            artist: nil,
                            duration: 0,
                            addedDate: addedDate
                        )
                    }
                }
                
                var result: [LibraryTrack] = []
                for await track in group {
                    if let track { result.append(track) }
                }
                return result
            }
        }
    }
}
