//
//  MoveToFolderNavigationContext.swift
//  TrackList
//
//  Тонкий навигационный контекст для MoveToFolderSheet.
//  НЕ содержит бизнес-логики, НЕ сканирует ФС, НЕ мутирует дерево.
//  Использует только read-only дерево папок из MusicLibraryManager.
//
//  Created by Pavel Fomin on 25.12.2025.
//

import Foundation
import SwiftUI

@MainActor
final class MoveToFolderNavigationContext: ObservableObject {

    // MARK: - Модель строки папки для UI

    struct FolderRow: Identifiable, Equatable {
        let id: UUID
        let name: String
        let hasSubfolders: Bool
    }

    // MARK: - Зависимости

    private let library: MusicLibraryManager

    // MARK: - Навигационное состояние (лёгкое)

    /// Текущая папка навигации. nil = корневой уровень.
    private(set) var currentFolderId: UUID? = nil

    /// Стек родительских папок для кнопки "Назад".
    private var stack: [UUID?] = []

    // MARK: - Публичные computed для UI

    var canGoBack: Bool { stack.isEmpty == false }

    var title: String {
        if let id = currentFolderId, let folder = library.folder(for: id) {
            return folder.name
        }
        return "Переместить в папку"
    }

    var rows: [FolderRow] {
        if let id = currentFolderId {
            guard let folder = library.folder(for: id) else { return [] }
            return folder.subfolders.map {
                FolderRow(
                    id: $0.url.libraryFolderId,
                    name: $0.name,
                    hasSubfolders: $0.subfolders.isEmpty == false
                )
            }
        }

        // Корневой уровень
        return library.attachedFolders.map {
            FolderRow(
                id: $0.url.libraryFolderId,
                name: $0.name,
                hasSubfolders: $0.subfolders.isEmpty == false
            )
        }
    }

    // MARK: - Init

    init(library: MusicLibraryManager) {
        self.library = library
    }

    // MARK: - Инициализация навигации по текущему треку

    /// Устанавливает навигационный путь так, чтобы пользователь
    /// видел расположение папки трека, не смешивая навигацию и destination.
    func initializeNavigation(to folderId: UUID?) {
        guard let folderId else { return }
        guard let path = findPath(to: folderId) else { return }

        // path: [root, ..., target]
        // target — папка, в которой лежит трек
        // Если target — leaf (без подпапок), навигационно
        // остаёмся на родителе, а не "входим" в неё
        if path.count >= 2 {
            let parentId = path[path.count - 2]
            stack = Array(path.dropLast(2))
            currentFolderId = parentId
        } else {
            // Корневая папка без подпапок — навигации нет
            stack = []
            currentFolderId = nil
        }

        objectWillChange.send()
    }
    
    // MARK: - Навигация

    func enter(_ folderId: UUID) {
        guard let folder = library.folder(for: folderId) else { return }
        guard folder.subfolders.isEmpty == false else { return }

        stack.append(currentFolderId)
        currentFolderId = folderId
        objectWillChange.send()
    }

    func goBack() {
        guard let prev = stack.popLast() else { return }
        currentFolderId = prev
        objectWillChange.send()
    }

    // MARK: - Поиск пути в дереве

    /// Ищет путь от корня до папки с указанным id.
    /// Возвращает массив folderId, начиная с root.
    private func findPath(to targetId: UUID) -> [UUID]? {
        for root in library.attachedFolders {
            if let path = findPath(in: root, targetId: targetId) {
                return path
            }
        }
        return nil
    }

    private func findPath(in folder: LibraryFolder, targetId: UUID) -> [UUID]? {
        let currentId = folder.url.libraryFolderId

        if currentId == targetId {
            return [currentId]
        }

        for sub in folder.subfolders {
            if let subPath = findPath(in: sub, targetId: targetId) {
                return [currentId] + subPath
            }
        }

        return nil
    }
}
