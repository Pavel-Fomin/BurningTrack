//
//  MoveToFolderNavigationContext.swift
//  TrackList
//
//  Тонкий навигационный контекст для MoveToFolderSheet.
//  НЕ содержит бизнес-логики, НЕ сканирует ФС, НЕ мутирует snapshot.
//  Использует только immutable presentation-модель папок.
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

    /// Снимок папок конкретного route, подготовленный feature factory.
    private let snapshot: MoveToFolderFolderSnapshot

    // MARK: - Навигационное состояние (лёгкое)

    /// Текущая папка навигации. nil = корневой уровень.
    private(set) var currentFolderID: UUID? = nil

    /// Стек родительских папок для кнопки "Назад".
    private var stack: [UUID?] = []

    // MARK: - Публичные вычисляемые свойства для интерфейса

    var canGoBack: Bool { stack.isEmpty == false }

    /// Имя открытой папки; nil означает корневой уровень выбора назначения.
    var currentFolderName: String? {
        guard let currentFolderID else { return nil }
        return node(for: currentFolderID)?.name
    }

    /// Строит UI-строки из snapshot, сохраняя virtual current-folder semantics корневого уровня.
    func rows(currentFolderID trackCurrentFolderID: UUID?) -> [FolderRow] {
        let baseRows = rowsForCurrentNavigationLevel()

        guard let trackCurrentFolderID else { return baseRows }

        if let currentIndex = baseRows.firstIndex(where: { $0.id == trackCurrentFolderID }) {
            let currentRow = baseRows[currentIndex]
            return [currentRow] + baseRows.enumerated().compactMap { index, row in
                index == currentIndex ? nil : row
            }
        }

        // Виртуальная текущая папка показывается только на root; внутри дерева строка естественная.
        guard currentFolderID == nil,
              let currentRow = row(for: trackCurrentFolderID) else {
            return baseRows
        }

        return [currentRow] + baseRows
    }

    // MARK: - Инициализация

    init(snapshot: MoveToFolderFolderSnapshot) {
        self.snapshot = snapshot
    }
    
    // MARK: - Навигация

    func enter(_ folderId: UUID) {
        guard let folder = node(for: folderId),
              folder.children.isEmpty == false else { return }

        stack.append(currentFolderID)
        currentFolderID = folderId
        objectWillChange.send()
    }

    func goBack() {
        guard let prev = stack.popLast() else { return }
        currentFolderID = prev
        objectWillChange.send()
    }

    /// Возвращает строки текущего navigation level в порядке зафиксированного snapshot.
    private func rowsForCurrentNavigationLevel() -> [FolderRow] {
        let nodes: [MoveToFolderFolderNode]

        if let currentFolderID {
            nodes = node(for: currentFolderID)?.children ?? []
        } else {
            nodes = snapshot.rootNodes
        }

        return nodes.map(FolderRow.init(node:))
    }

    /// Находит узел в immutable tree без обращения к внешнему источнику папок.
    private func node(for id: UUID) -> MoveToFolderFolderNode? {
        Self.node(for: id, in: snapshot.rootNodes)
    }

    /// Рекурсивно ищет presentation-узел в уже подготовленном snapshot.
    private static func node(
        for id: UUID,
        in nodes: [MoveToFolderFolderNode]
    ) -> MoveToFolderFolderNode? {
        for node in nodes {
            if node.id == id {
                return node
            }

            if let nestedNode = Self.node(for: id, in: node.children) {
                return nestedNode
            }
        }

        return nil
    }

    /// Строит UI-строку без раскрытия model detail в Sheet.
    private func row(for id: UUID) -> FolderRow? {
        node(for: id).map(FolderRow.init(node:))
    }
}

private extension MoveToFolderNavigationContext.FolderRow {
    /// Преобразует immutable node в компактную строку навигации.
    init(node: MoveToFolderFolderNode) {
        id = node.id
        name = node.name
        hasSubfolders = node.children.isEmpty == false
    }
}
