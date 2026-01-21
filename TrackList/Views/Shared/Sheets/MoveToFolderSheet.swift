//
//  MoveToFolderSheet.swift
//  TrackList
//
//  UI-форма выбора папки для перемещения трека.
//
//  Роль компонента:
//  - отображает дерево папок
//  - позволяет выбрать папку назначения
//  - управляет локальной навигацией внутри дерева папок
//
//  Архитектурные принципы:
//  - не содержит бизнес-логики
//  - не выполняет команд перемещения
//  - не управляет закрытием sheet’а
//  - подтверждение и отмена обрабатываются контейнером
//
//  Created by Pavel Fomin on 07.12.2025.
//

import SwiftUI
import Foundation

struct MoveToFolderSheet: View {

    // MARK: - Input

    /// Идентификатор трека, для которого выполняется перемещение.
    /// Используется ТОЛЬКО для определения текущей папки (бейдж "Текущая").
    let trackId: UUID

    /// Выбранная папка назначения.
    /// Источник истины находится в контейнере.
    @Binding var selectedFolderId: UUID?

    /// Текущая папка трека.
    /// Используется для бейджа "Текущая" и валидации.
    @Binding var trackCurrentFolderId: UUID?

    // MARK: - State

    /// Контекст навигации по дереву папок.
    /// Управляет переходами внутрь подпапок и возвратами назад.
    @StateObject private var nav = MoveToFolderNavigationContext(
        library: MusicLibraryManager.shared
    )

    // MARK: - Rows

    /// Строки папок для отображения в списке.
    ///
    /// Правила:
    /// - текущая папка трека показывается виртуально ТОЛЬКО на корневом уровне
    /// - внутри дерева отображается только естественным образом
    private var orderedRows: [MoveToFolderNavigationContext.FolderRow] {

        let rows = nav.rows

        // Пока текущая папка ещё не загружена — показываем список как есть
        guard let currentId = trackCurrentFolderId else {
            return rows
        }

        // Если текущая папка уже есть в списке — просто поднимаем её наверх
        if rows.contains(where: { $0.id == currentId }) {
            return rows.sorted { lhs, rhs in
                if lhs.id == currentId { return true }
                if rhs.id == currentId { return false }
                return false
            }
        }

        // Виртуально добавляем текущую папку ТОЛЬКО на корневом уровне
        guard nav.currentFolderId == nil else {
            return rows
        }

        guard let currentFolder = MusicLibraryManager.shared.folder(for: currentId) else {
            return rows
        }

        let currentRow = MoveToFolderNavigationContext.FolderRow(
            id: currentId,
            name: currentFolder.name,
            hasSubfolders: currentFolder.subfolders.isEmpty == false
        )

        return [currentRow] + rows
    }

    // MARK: - UI

    var body: some View {
        List(orderedRows) { row in
            HStack(spacing: 12) {

                // Левая зона — навигация (переход в подпапку)
                Button {
                    nav.enter(row.id)
                } label: {
                    HStack(spacing: 10) {
                        Text(row.name)
                            .lineLimit(1)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                // Правая зона — выбор папки назначения (radio)
                // Показывается ТОЛЬКО для папок без подпапок и не для текущей папки
                if row.id != trackCurrentFolderId && row.hasSubfolders == false {
                    Button {
                        selectedFolderId =
                            (selectedFolderId == row.id) ? nil : row.id
                    } label: {
                        Image(
                            systemName:
                                selectedFolderId == row.id
                                ? "largecircle.fill.circle"
                                : "circle"
                        )
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    // Пустое место под radio, чтобы не ломать layout
                    Spacer()
                        .frame(width: 28)
                }
            }
            .overlay(alignment: .trailing) {

                // Бейдж "Текущая"
                if row.id == trackCurrentFolderId {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                        .frame(width: 28, height: 28)
                }
            }
            .listRowBackground(Color(.tertiarySystemBackground))
        }
        .navigationTitle(nav.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Кнопка "Назад" появляется только если мы реально углубились
            ToolbarItem(placement: .topBarLeading) {
                if nav.canGoBack {
                    Button {
                        nav.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                    }
                }
            }
        }
    }
}
