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

    @Published private(set) var isAccessRestored = false       /// Флаг, что восстановление доступа к папкам завершено
    @Published var attachedFolders: [LibraryFolder] = []       /// Прикреплённые корневые папки (дерево подпапок и файлов для UI)
    @Published private(set) var attachingFolderIds: Set<UUID> = [] /// Папки, которые сейчас прикрепляются и сканируются
   
    enum LibraryAccessState {
        case booting
        case ready
        case failed
    }

    @Published private(set) var accessState: LibraryAccessState = .booting
    
    // MARK: - Приватные зависимости

    private let scanner = LibraryScanner()
    
    // MARK: - Security-scoped доступы (держим открытыми весь runtime)

    private var activeRootFolderAccess: [UUID: URL] = [:]    /// Активные root-доступы: если папка прикреплена — доступ держим открытым.

    // MARK: - Инициализация

    init() {
        // Восстанавливаем доступ к папкам (быстро) и затем запускаем синк (в фоне)
        Task { [weak self] in
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

    /// Проверяет, находится ли папка в процессе прикрепления.
    func isAttachingFolder(_ folderId: UUID) -> Bool {
        attachingFolderIds.contains(folderId)
    }

    /// Сохраняет фактический порядок прикреплённых root-папок в SQLite.
    func saveAttachedFoldersOrder(
        _ orderedIds: [UUID]
    ) async throws {
        try await TrackRegistry.shared.updateRootFoldersOrder(orderedIds)
    }

    /// Заменяет опубликованный порядок прикреплённых папок после успешного сохранения.
    func replaceAttachedFolders(
        with folders: [LibraryFolder]
    ) {
        attachedFolders = folders
    }

    /// Проверяет, удерживается ли root-доступ к папке на весь runtime.
    func hasActiveRootAccess(rootFolderId: UUID, url: URL) -> Bool {
        guard let activeURL = activeRootFolderAccess[rootFolderId] else { return false }

        let activePath = activeURL.standardizedFileURL.resolvingSymlinksInPath().path
        let requestedPath = url.standardizedFileURL.resolvingSymlinksInPath().path

        return activePath == requestedPath
    }

    // MARK: - Добавление папки: сохраняем bookmark, регистрируем, синхронизируем

    func saveBookmark(for url: URL) async throws {
        // 0. Bootstrap-доступ
        guard url.startAccessingSecurityScopedResource() else {
            throw AppError.libraryFolderAccessDenied
        }

        // Держим доступ открытым на весь runtime (как для восстановленных папок)
        let rootFolderId = url.libraryFolderId
        activeRootFolderAccess[rootFolderId] = url

        // Сразу показываем папку в UI, чтобы пользователь видел начало прикрепления
        let liteRootFolder = liteFolder(from: url)
        if attachedFolders.contains(where: { $0.id == rootFolderId }) == false {
            attachedFolders.insert(liteRootFolder, at: 0)
        }
        attachingFolderIds.insert(rootFolderId)

        do {
            // 1. Создание bookmark для корневой папки
            guard let bookmarkBase64 = BookmarkResolver.makeBookmarkBase64(for: url) else {
                attachingFolderIds.remove(rootFolderId)
                attachedFolders.removeAll { $0.id == rootFolderId }
                activeRootFolderAccess.removeValue(forKey: rootFolderId)
                url.stopAccessingSecurityScopedResource()
                throw AppError.bookmarkCreateFailed
            }

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
            try await LibrarySyncModule.shared.syncRootFolder(
                rootFolderId: rootFolderId,
                rootURL: url,
                mode: .full,
                logsDatabaseDiagnostics: false
            )

            // 5. Заменяем lite-папку на полноценное дерево
            if let index = attachedFolders.firstIndex(where: { $0.id == rootFolderId }) {
                attachedFolders[index] = rootTree
            } else {
                attachedFolders.insert(rootTree, at: 0)
            }

            attachingFolderIds.remove(rootFolderId)

            #if DEBUG
            // Диагностика attach показывает итоговое состояние SQLite после регистрации корня и sync.
            DatabaseDiagnosticsLogger.logLibrarySnapshot()
            #endif
        } catch {
            attachingFolderIds.remove(rootFolderId)
            attachedFolders.removeAll { $0.id == rootFolderId }
            activeRootFolderAccess.removeValue(forKey: rootFolderId)
            url.stopAccessingSecurityScopedResource()
            throw error
        }
    }

    // MARK: - Удаление прикреплённой папки

    func removeBookmark(for url: URL) async throws {

        // Получаем id корневой папки из её URL
        let rootFolderId = url.libraryFolderId

        // Закрываем активный доступ к папке (security-scoped resource),
        // если он был открыт ранее при restoreAccess
        if let activeURL = activeRootFolderAccess[rootFolderId] {
            activeURL.stopAccessingSecurityScopedResource()
            activeRootFolderAccess.removeValue(forKey: rootFolderId)
        }

        // Получаем все треки, принадлежащие этой корневой папке
        let tracksInFolder = await TrackRegistry.shared.tracks(inRootFolder: rootFolderId)

        // Удаляем bookmarks для каждого трека из этой папки
        for track in tracksInFolder {
            await BookmarksRegistry.shared.removeTrackBookmark(id: track.id)
        }

        // Удаляем bookmark самой папки
        await BookmarksRegistry.shared.removeFolderBookmark(id: rootFolderId)

        // Удаляем папку и связанные с ней треки из TrackRegistry
        await TrackRegistry.shared.removeFolder(id: rootFolderId)

        // Финально проверяем записи в SQLite после обновления реестров.
        // Если запись не прошла, ошибка должна дойти до UI,
        // чтобы success-toast не был показан ложно.
        try await BookmarksRegistry.shared.throwPendingPersistenceError()
        try await TrackRegistry.shared.throwPendingPersistenceError()

        // Сигнал отправляется после полного удаления папки и её треков из SQLite.
        NotificationCenter.default.post(name: .libraryDataDidChange, object: nil)

        // Обновляем UI-список прикреплённых папок
        attachedFolders.removeAll { $0.url == url }

        #if DEBUG
        // Диагностика detach показывает фактическое состояние SQLite после удаления корня.
        DatabaseDiagnosticsLogger.logLibrarySnapshot()
        #endif
    }
    
    // MARK: - Проверка перед откреплением папки
    
    func canDetachFolder(
        url: URL,
        currentTrackId: UUID?,
        isPlaying: Bool
    ) async -> Bool {

        // Если ничего не играет — можно откреплять
        if !isPlaying {return true}

        let rootFolderId = url.libraryFolderId

        // Проверяем: текущий трек принадлежит этой папке
        if let currentTrackId,
           let entry = await TrackRegistry.shared.entry(for: currentTrackId),
           entry.rootFolderId == rootFolderId {
            return false
        }

        return true
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

    /// Возвращает прикреплённую корневую папку, внутри которой находится folderId.
    /// Bookmark хранится только для корня, поэтому файловые операции в подпапках
    /// должны открывать security-scoped доступ именно к найденному корню.
    func rootFolder(for folderId: UUID) -> LibraryFolder? {
        for root in attachedFolders {
            if contains(folderId: folderId, in: root) {
                return root
            }
        }
        return nil
    }

    // MARK: - Восстановление прикреплённых папок при запуске

    func restoreAccessAsync() async {
        print("🔁 Восстановление доступа к папкам…")
        PersistentLogger.log("🔁 Восстановление доступа к папкам…")
        PersistentLogger.log("🔁 restoreAccessAsync: start")
        
        accessState = .booting
        
        // Сбрасываем предыдущее состояние (на случай повторного вызова)
        for (_, url) in activeRootFolderAccess {
            url.stopAccessingSecurityScopedResource()
        }
        activeRootFolderAccess.removeAll()
        attachedFolders = []
        isAccessRestored = false
        
        // 1) Загружаем реестры (синхронные методы в actor'ах)
        await TrackRegistry.shared.load()
        await BookmarksRegistry.shared.load()
        
        PersistentLogger.log("📘 TrackRegistry loaded")
        PersistentLogger.log("🔑 BookmarksRegistry loaded")
        
        // 2) Берём мета папок
        let foldersMeta = await TrackRegistry.shared.allFolders()
        if foldersMeta.isEmpty {
            print("ℹ️ Нет сохранённых папок")
            PersistentLogger.log("ℹ️ restoreAccessAsync: no foldersMeta")
            
            accessState = .ready
            isAccessRestored = true
            PersistentLogger.log("✅ restoreAccessAsync: ready (no folders)")
            
            #if DEBUG
            // Диагностика запуска полезна даже при пустой фонотеке.
            DatabaseDiagnosticsLogger.logLibrarySnapshot()
            #endif

            NotificationCenter.default.post(name: .libraryAccessRestored, object: nil)
            return
        }
        
        // 3) Быстрый restore: резолвим URL, открываем доступ, строим lite-модель (без рекурсии)
        var liteFolders: [LibraryFolder] = []
        var rootsToSync: [(id: UUID, url: URL, name: String)] = []
        
        for folder in foldersMeta {
            guard let url = await BookmarkResolver.url(forFolder: folder.id) else {
                print("⚠️ Не удалось восстановить URL папки:", folder.name)
                PersistentLogger.log("⚠️ restoreAccessAsync: folder url not resolved: \(folder.name)")
                continue
            }
            
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ restoreAccessAsync: нет доступа к папке:", folder.name)
                PersistentLogger.log("❌ restoreAccessAsync: startAccessing failed: \(folder.name)")
                continue
            }
            
            activeRootFolderAccess[folder.id] = url
            liteFolders.append(liteFolder(from: url))
            rootsToSync.append((folder.id, url, folder.name))
            
            print("✅ Root-доступ открыт:", folder.name)
            PersistentLogger.log("✅ restoreAccessAsync: root access opened: \(folder.name)")
        }
        
        if rootsToSync.isEmpty {
            accessState = .failed
            isAccessRestored = true
            
            PersistentLogger.log("❌ restoreAccessAsync: no root access opened")
            print("❌ restoreAccessAsync: не удалось открыть ни одну корневую папку")

            #if DEBUG
            // Диагностика фиксирует состояние БД после неуспешной попытки восстановления доступа.
            DatabaseDiagnosticsLogger.logLibrarySnapshot()
            #endif

            return
        }
        
        // 4) Обновляем UI сразу
        attachedFolders = liteFolders

        // После быстрого lite-состояния пересобираем UI-дерево папок.
        // Lite-модель нужна только для быстрого первого отображения,
        // но экран фонотеки должен получать реальные подпапки и собственные аудиофайлы.
        var restoredTrees: [LibraryFolder] = []
        for root in rootsToSync {
            let tree = await buildFolderTree(from: root.url)
            restoredTrees.append(tree)
        }
        attachedFolders = restoredTrees
        
        /// Доступ к библиотеке подтверждён:
        /// хотя бы одна корневая папка успешно открыта.
        accessState = .ready
        PersistentLogger.log("🔄 restoreAccessAsync: sync roots count = \(rootsToSync.count)")
        
        /// Сначала выполняем безопасную синхронизацию без удалений.
        for root in rootsToSync {
            do {
                try await LibrarySyncModule.shared.syncRootFolder(
                    rootFolderId: root.id,
                    rootURL: root.url,
                    mode: .safe,
                    logsDatabaseDiagnostics: false
                )
                print("🔄 Safe sync завершён:", root.name)
            } catch {
                print("❌ Safe sync не завершён:", root.name, error)
                PersistentLogger.log("❌ restoreAccessAsync: safe sync failed: \(root.name), error: \(error)")
            }
        }
        
        /// После безопасной синхронизации выполняем полную.
        for root in rootsToSync {
            do {
                try await LibrarySyncModule.shared.syncRootFolder(
                    rootFolderId: root.id,
                    rootURL: root.url,
                    mode: .full,
                    logsDatabaseDiagnostics: false
                )
                print("🔄 Full sync завершён:", root.name)
            } catch {
                print("❌ Full sync не завершён:", root.name, error)
                PersistentLogger.log("❌ restoreAccessAsync: full sync failed: \(root.name), error: \(error)")
            }
        }
        
        PersistentLogger.log("✅ restoreAccessAsync: sync finished")
        isAccessRestored = true
        print("✅ Восстановление доступа завершено (ready)")
        PersistentLogger.log("✅ Восстановление доступа завершено (ready)")
        PersistentLogger.log("✅ restoreAccessAsync: ready")

        #if DEBUG
        // Диагностика restore печатается один раз после всех safe/full sync корневых папок.
        DatabaseDiagnosticsLogger.logLibrarySnapshot()
        #endif
        
        NotificationCenter.default.post(name: .libraryAccessRestored, object: nil)
    }
    
    // MARK: - Sync фасад для ViewModel

    /// Синхронизирует фонотеку для папки.
    /// Работает корректно даже для пустых папок.
    func syncFolderIfNeeded(folderId: UUID) async {

        // 1. Определяем rootFolderId
        // Если folderId — корневая папка, используем его напрямую.
        // Иначе поднимаемся к корню через дерево папок.
        let rootFolderId: UUID

        if let folder = await TrackRegistry.shared.allFolders()
            .first(where: { $0.id == folderId }) {
            rootFolderId = folder.id
        } else {
            // Подпапка: ищем root в дереве attachedFolders.
            guard let root = rootFolder(for: folderId) else {
                print("❌ Root folder не найден для folderId: \(folderId)")
                return
            }

            do {
                try await LibrarySyncModule.shared.syncRootFolder(
                    rootFolderId: root.id,
                    rootURL: root.url,
                    mode: .safe
                )
            } catch {
                print("❌ syncFolderIfNeeded: sync failed:", error)
                PersistentLogger.log("❌ syncFolderIfNeeded: sync failed for nested folder: \(folderId), error: \(error)")
            }

            return
        }

        // 2. Резолвим URL корневой папки
        guard let rootURL = await BookmarkResolver.url(forFolder: rootFolderId) else {
            print("⚠️ syncFolderIfNeeded: не удалось восстановить URL корневой папки")
            return
        }

        // 3. Запускаем sync
        do {
            try await LibrarySyncModule.shared.syncRootFolder(
                rootFolderId: rootFolderId,
                rootURL: rootURL,
                mode: .safe
            )
        } catch {
            print("❌ syncFolderIfNeeded: sync failed:", error)
            PersistentLogger.log("❌ syncFolderIfNeeded: sync failed for root folder: \(rootFolderId), error: \(error)")
        }
    }
    

    // MARK: - Приватные помощники: дерево

    /// Рекурсивный поиск folderId в дереве
    private func contains(folderId: UUID, in folder: LibraryFolder) -> Bool {
        if folder.id == folderId { return true }
        for sub in folder.subfolders {
            if contains(folderId: folderId, in: sub) { return true }
        }
        return false
    }

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
