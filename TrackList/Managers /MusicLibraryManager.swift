//
//  MusicLibraryManager.swift
//  TrackList
//
//  Управляет доступом к прикреплённым папкам фонотеки, использует:
//  - LibraryScanner для обхода файловой системы (только для построения UI-дерева)
//  - TrackRegistry для хранения метаданных
//  - BookmarksRegistry для хранения bookmark'ов.
//  — Синхронизация файлов фонотеки с реестрами выполняется ТОЛЬКО через LibrarySyncModule.
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

    // MARK: - Добавление папки: сохраняем bookmark, регистрируем, синхронизируем

    func saveBookmark(for url: URL) {
        Task {
            // 0. Bootstrap-доступ
            let started = url.startAccessingSecurityScopedResource()
            if !started {
                print("❌ saveBookmark: не удалось начать доступ к папке:", url.path)
                return
            }

            // Гарантированно закрываем доступ после завершения операции
            defer {
                url.stopAccessingSecurityScopedResource()
            }

            // 1. Создание bookmark для корневой папки
            guard let bookmarkBase64 = BookmarkResolver.makeBookmarkBase64(for: url) else {
                print("❌ saveBookmark: не удалось создать bookmark для папки")
                return
            }

            let rootFolderId = url.libraryFolderId
            let rootFolderName = url.lastPathComponent

            await BookmarksRegistry.shared.upsertFolderBookmark(
                id: rootFolderId,
                base64: bookmarkBase64
            )

            // 2. Строим дерево папки для UI (сканер используется только для UI-модели)
            let rootTree = await buildFolderTree(from: url)

            // 3. Регистрируем саму папку (только метаданные)
            await TrackRegistry.shared.upsertFolder(
                id: rootFolderId,
                name: rootFolderName
            )

            // 4. Синхронизируем реестры по фактическому состоянию ФС (ТОЛЬКО через sync-модуль)
            await LibrarySyncModule.shared.syncRootFolder(
                rootFolderId: rootFolderId,
                rootURL: url
            )

            // 5. Обновляем UI
            await MainActor.run {
                if attachedFolders.contains(where: { $0.url == url }) == false {
                    attachedFolders.insert(rootTree, at: 0)
                }
            }

            print("📁 Папка добавлена и синхронизирована:", rootFolderName)
        }
    }

    // MARK: - Удаление прикреплённой папки

    func removeBookmark(for url: URL) {
        Task {
            let rootFolderId = url.libraryFolderId

            // 1. Получаем треки
            let tracksInFolder = await TrackRegistry.shared.tracks(inRootFolder: rootFolderId)

            // 2. Удаляем bookmarks всех треков
            for track in tracksInFolder {
                await BookmarksRegistry.shared.removeTrackBookmark(id: track.id)
            }

            // 3. Удаляем bookmark папки
            await BookmarksRegistry.shared.removeFolderBookmark(id: rootFolderId)

            // 4. Удаляем папку и треки из TrackRegistry
            await TrackRegistry.shared.removeFolder(id: rootFolderId)

            // 5. Persist
            await TrackRegistry.shared.persist()
            await BookmarksRegistry.shared.persist()

            // 6. UI
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

        // 1) Загружаем информацию из реестров
        await TrackRegistry.shared.load()
        await BookmarksRegistry.shared.load()

        // 2) Получаем список всех сохранённых папок
        let foldersMeta = await TrackRegistry.shared.allFolders()

        if foldersMeta.isEmpty {
            print("ℹ️ Нет сохранённых папок")
            self.isAccessRestored = true
            self.isInitialFoldersLoadFinished = true
            return
        }

        var restoredTrees: [LibraryFolder] = []

        // 3) Восстанавливаем только те папки, у которых есть bookmark
        for folder in foldersMeta {
            guard let url = await BookmarkResolver.url(forFolder: folder.id) else {
                print("⚠️ Не удалось восстановить URL папки:", folder.name)
                continue
            }

            // 4) Строим дерево папки для UI
            let tree = await buildFolderTree(from: url)
            restoredTrees.append(tree)

            // 5) Синхронизируем реестры по фактическому состоянию ФС
            await LibrarySyncModule.shared.syncRootFolder(
                rootFolderId: folder.id,
                rootURL: url
            )

            print(
                "🌳 BUILT TREE:", tree.name,
                "subfolders:", tree.subfolders.count,
                "audio:", tree.audioFiles.count
            )

            print("✅ Доступ к папке восстановлен:", folder.name)
        }

        // 6) Обновляем UI
        self.attachedFolders = restoredTrees
        self.isAccessRestored = true
        self.isInitialFoldersLoadFinished = true

        print("✅ Восстановление доступа завершено")
    }
    
    // MARK: - Sync фасад для ViewModel

    /// Синхронизирует фонотеку для папки.
    /// Работает корректно даже для пустых папок.
    func syncFolderIfNeeded(folderId: UUID) async {

        // 1. Определяем rootFolderId
        // Если folderId — корневая папка, используем его напрямую.
        // Иначе поднимаемся к корню через реестр треков (если есть).
        let rootFolderId: UUID

        if let folder = await TrackRegistry.shared.allFolders()
            .first(where: { $0.id == folderId }) {
            rootFolderId = folder.id
        } else {
            // Подпапка: ищем любой трек и берём его rootFolderId
            let entries = await TrackRegistry.shared.tracks(inFolder: folderId)
            guard let first = entries.first else {
                // Пустая подпапка без треков — синк всё равно нужен,
                // но rootFolderId восстановить нельзя без корня.
                // В этом случае корректнее просто выйти.
                return
            }
            rootFolderId = first.rootFolderId
        }

        // 2. Резолвим URL корневой папки
        guard let rootURL = await BookmarkResolver.url(forFolder: rootFolderId) else {
            print("⚠️ syncFolderIfNeeded: не удалось восстановить URL корневой папки")
            return
        }

        // 3. Запускаем sync
        await LibrarySyncModule.shared.syncRootFolder(
            rootFolderId: rootFolderId,
            rootURL: rootURL
        )
    }
    

    // MARK: - Приватные помощники: дерево

    /// Рекурсивно строит дерево LibraryFolder из файловой системы через LibraryScanner.
    /// Важно: используется только для UI и навигации по фонотеке.
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
}
