//
//  MoveToFolderScreenState.swift
//  TrackList
//
//  Presentation-состояние и снимок дерева папок Move To Folder.
//
//  Created by Pavel Fomin on 15.08.2026.
//

import Foundation

/// Неизменяемый узел дерева папок, подготовленный для одного UI-сеанса выбора назначения.
struct MoveToFolderFolderNode: Identifiable, Equatable {
    /// Стабильная идентичность папки назначения.
    let id: UUID
    /// Готовое имя строки navigation UI.
    let name: String
    /// Вложенные папки в порядке фонотеки.
    let children: [MoveToFolderFolderNode]

    /// Создаёт node из уже подготовленных presentation-значений.
    init(
        id: UUID,
        name: String,
        children: [MoveToFolderFolderNode]
    ) {
        self.id = id
        self.name = name
        self.children = children
    }

    /// Преобразует доменное дерево в лёгкую presentation-модель вне View.
    init(folder: LibraryFolder) {
        id = folder.id
        name = folder.name
        children = folder.subfolders.map(MoveToFolderFolderNode.init(folder:))
    }
}

/// Фиксирует дерево папок на время конкретного route, не раскрывая MusicLibraryManager в SwiftUI.
struct MoveToFolderFolderSnapshot: Equatable {
    /// Корневые прикреплённые папки в отображаемом порядке.
    let rootNodes: [MoveToFolderFolderNode]

    /// Создаёт snapshot из уже подготовленного manager-ом дерева.
    init(folders: [LibraryFolder]) {
        rootNodes = folders.map(MoveToFolderFolderNode.init(folder:))
    }

    /// Позволяет собирать контролируемое дерево в focused-тестах.
    init(rootNodes: [MoveToFolderFolderNode]) {
        self.rootNodes = rootNodes
    }
}

/// Готовое presentation-состояние выбора папки назначения.
struct MoveToFolderScreenState: Equatable {
    /// Заголовок верхнего уровня в зависимости от move или Purchased iTunes copy.
    let navigationTitle: String
    /// Неизменяемое дерево папок конкретного sheet-сеанса.
    let folderSnapshot: MoveToFolderFolderSnapshot
    /// Выбранная папка назначения.
    let selectedFolderID: UUID?
    /// Текущая папка локального трека; для Purchased iTunes copy всегда nil.
    let currentFolderID: UUID?
    /// Блокирует повторный submit, пока выполняется файловая команда.
    let isPerformingOperation: Bool
    /// Разрешает submit только для доступной папки, отличной от текущей.
    let canSubmit: Bool
}
