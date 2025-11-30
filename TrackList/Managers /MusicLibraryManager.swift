//
//  MusicLibraryManager.swift
//  TrackList
//
//  Управляет доступом к прикреплённым папкам фонотеки, использует:
//  - LibraryScanner для обхода файловой системы
//  - TrackRegistry для хранения метаданных
//  - BookmarksRegistry для хранения bookmark'ов.
//
//  Created by Pavel Fomin on 22.06.2025.
//  Переписано под новую архитектуру в 2025.
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
    
    /// Флаг, что восстановление доступа к папкам завершено
    @Published private(set) var isAccessRestored = false
    
    /// Прикреплённые корневые папки (дерево подпапок и файлов для UI)
    @Published var attachedFolders: [LibraryFolder] = []
    
  
    /// Флаг, что начальная загрузка списка папок завершена
    @Published var isInitialFoldersLoadFinished: Bool = false
    
    // MARK: - Приватные зависимости
    
    private let scanner = LibraryScanner()
    
    // MARK: - Инициализация
    
    init() {
        // Восстанавливаем доступ к папкам и структуру фонотеки
        Task.detached(priority: .background) { [weak self] in
            await self?.restoreAccessAsync()
        }
    }
    
    // MARK: - Лёгкая модель папки (плоская, без рекурсии)
    
    func liteFolder(from url: URL) -> LibraryFolder {
        LibraryFolder(
            name: url.lastPathComponent,
            url: url,
            subfolders: [],
            audioFiles: []
        )
    }
    
    
    
    // MARK: - Добавление папки: сохраняем bookmark, сканируем, регистрируем

    func saveBookmark(for url: URL) {
        // Начинаем доступ к папке
        guard url.startAccessingSecurityScopedResource() else {
            print("❌ Не удалось начать доступ к папке")
            return
        }

        Task {
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                // Bookmark для корневой папки
                let bookmarkData = try url.bookmarkData()
                let bookmarkBase64 = bookmarkData.base64EncodedString()

                let rootFolderId = url.libraryFolderId
                let rootFolderName = url.lastPathComponent

                // 1) Сохраняем bookmark корневой папки
                await BookmarksRegistry.shared.upsertFolderBookmark(
                    id: rootFolderId,
                    base64: bookmarkBase64
                )

                // 2) Строим дерево через LibraryScanner (рекурсивно)
                let rootTree = await buildFolderTree(from: url)

                // Регистрируем только root
                await TrackRegistry.shared.upsertFolder(
                    id: rootFolderId,
                    name: rootFolderName
                )
                
                // 4) Собираем все аудиофайлы во всём дереве и регистрируем треки + bookmark'и
                let allFileURLs = collectFileURLs(from: rootTree)

                for fileURL in allFileURLs {
                    let trackId = UUID.v5(from: fileURL.path)
                    let folderId = fileURL.deletingLastPathComponent().libraryFolderId

                    // TrackRegistry — только метаданные
                    await TrackRegistry.shared.upsertTrack(
                        id: trackId,
                        fileName: fileURL.lastPathComponent,
                        folderId: folderId
                    )

                    // BookmarksRegistry — bookmark конкретного файла
                    if let fileBookmark = try? fileURL.bookmarkData() {
                        await BookmarksRegistry.shared.upsertTrackBookmark(
                            id: trackId,
                            base64: fileBookmark.base64EncodedString()
                        )
                    }
                }

                // 5) Persist — один раз в конце
                await TrackRegistry.shared.persist()
                await BookmarksRegistry.shared.persist()

                // 6) UI: пересобираем дерево для attachedFolders
                await MainActor.run {
                    if attachedFolders.contains(where: { $0.url == url }) == false {
                        attachedFolders.insert(rootTree, at: 0)
                    }
                }

                print("📁 Папка добавлена и проиндексирована: \(rootFolderName)")

            } catch {
                print("❌ Ошибка сохранения bookmark папки:", error)
            }
        }
    }
    
    // MARK: - Удаление прикреплённой папки

    func removeBookmark(for url: URL) {
        Task {
            let rootFolderId = url.libraryFolderId

            // 1) Удаляем root-папку из TrackRegistry
            //    Это автоматически удалит ВСЕ треки, у которых folderId == rootFolderId
            await TrackRegistry.shared.removeFolder(id: rootFolderId)

            // 2) Строим дерево root-папки → собираем все файлы
            //    Это нужно только для удаления trackBookmarks
            let rootTree = await buildFolderTree(from: url)
            let allFileURLs = collectFileURLs(from: rootTree)

            // 3) Удаляем trackBookmarks только для файлов root
            for fileURL in allFileURLs {
                let trackId = UUID.v5(from: fileURL.path)
                await BookmarksRegistry.shared.removeTrackBookmark(id: trackId)
            }

            // 4) Удаляем bookmark root-папки
            await BookmarksRegistry.shared.removeFolderBookmark(id: rootFolderId)

            // 5) Persist
            await TrackRegistry.shared.persist()
            await BookmarksRegistry.shared.persist()

            // 6) UI: удаляем из списка прикреплённых
            await MainActor.run {
                attachedFolders.removeAll { $0.url == url }
            }

            print("📁 Папка откреплена:", url.lastPathComponent)
        }
    }
    
    // MARK: - Поиск папки по ID (через дерево attachedFolders)
    
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
    
    // MARK: - Восстановление прикреплённых папок при запуске

    func restoreAccessAsync() async {
        print("🔁 Восстановление доступа к папкам…")

        // 1) Загружаем метаданные и bookmark'и
        await TrackRegistry.shared.load()
        await BookmarksRegistry.shared.load()

        // 2) Берём список ВСЕХ папок из реестра
        let foldersMeta = await TrackRegistry.shared.allFolders()

        if foldersMeta.isEmpty {
            print("ℹ️ Нет сохранённых папок")
            self.isAccessRestored = true
            self.isInitialFoldersLoadFinished = true
            return
        }

        var restoredTrees: [LibraryFolder] = []

        // 3) Восстанавливаем только те папки, у которых есть bookmark (root)
        for folder in foldersMeta {
            guard
                let base64 = await BookmarksRegistry.shared.folderBookmark(for: folder.id),
                let data = Data(base64Encoded: base64)
            else { continue }

            do {
                var stale = false

                // 4) Восстановили URL через bookmark
                let url = try URL(
                    resolvingBookmarkData: data,
                    options: [.withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale
                )

                if stale { print("⚠️ Bookmark устарел: \(folder.name)") }

                let accessed = url.startAccessingSecurityScopedResource()

                // 5) Строим дерево для UI
                let tree = await buildFolderTree(from: url)
                
                print("🌳 BUILT TREE:", tree.name,
                      "subfolders:", tree.subfolders.count,
                      "audio:", tree.audioFiles.count)
                restoredTrees.append(tree)

                if accessed {
                    // Не вызываем stopAccessing: пусть остаётся активный доступ
                }

                print("✅ Доступ к папке восстановлен:", folder.name)

            } catch {
                print("❌ Ошибка восстановления bookmark:", folder.name, error)
            }
        }

        // 6) Обновляем UI
        self.attachedFolders = restoredTrees
        self.isAccessRestored = true
        self.isInitialFoldersLoadFinished = true

        print("✅ Восстановление доступа завершено")
    }
    
    // MARK: - Приватные помощники: дерево и коллекции URL
    
    /// Рекурсивно строит дерево LibraryFolder из файловой системы через LibraryScanner.
    private func buildFolderTree(from folderURL: URL) async -> LibraryFolder {
        let scanned = await scanner.scanFolder(folderURL)
        
        var subfoldersModels: [LibraryFolder] = []
        
        for subURL in scanned.subfolders {
            let child = await buildFolderTree(from: subURL)
            subfoldersModels.append(child)
        }
        
        return LibraryFolder(
            name: scanned.name,
            url: scanned.url.resolvingSymlinksInPath(),
            subfolders: subfoldersModels,
            audioFiles: scanned.audioFiles
        )
    }
    
    /// Собирает все URL папок (корневая + все вложенные).
    private func collectFolderURLs(from folder: LibraryFolder) -> [URL] {
        var result: [URL] = [folder.url]
        for sub in folder.subfolders {
            result.append(contentsOf: collectFolderURLs(from: sub))
        }
        return result
    }
    
    /// Собирает все URL файлов из дерева папок.
    private func collectFileURLs(from folder: LibraryFolder) -> [URL] {
        var result: [URL] = folder.audioFiles
        for sub in folder.subfolders {
            result.append(contentsOf: collectFileURLs(from: sub))
        }
        return result
    }
}
