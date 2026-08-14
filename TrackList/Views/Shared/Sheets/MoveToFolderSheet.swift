//
//  MoveToFolderSheet.swift
//  TrackList
//
//  Отображает дерево папок и передаёт локальный выбор контейнеру.
//
//  Created by Pavel Fomin on 07.12.2025.
//

import SwiftUI
import Foundation

struct MoveToFolderSheet: View {

    // MARK: - Входные данные

    /// Идентификатор трека нужен только для отметки его текущей папки.
    let trackId: UUID

    let rootNavigationTitle: String

    /// Выбранная папка назначения.
    /// Источник истины находится в контейнере.
    @Binding var selectedFolderId: UUID?

    /// Текущая папка трека нужна для отметки и исключается из доступных папок назначения.
    @Binding var trackCurrentFolderId: UUID?

    /// Явно переданное read-only дерево папок для navigation context и virtual current row.
    let library: MusicLibraryManager

    // MARK: - Состояние

    /// Сохраняет путь внутри дерева при пересчётах родительского View.
    @StateObject private var nav: MoveToFolderNavigationContext

    init(
        trackId: UUID,
        rootNavigationTitle: String,
        selectedFolderId: Binding<UUID?>,
        trackCurrentFolderId: Binding<UUID?>,
        library: MusicLibraryManager
    ) {
        self.trackId = trackId
        self.rootNavigationTitle = rootNavigationTitle
        _selectedFolderId = selectedFolderId
        _trackCurrentFolderId = trackCurrentFolderId
        self.library = library
        _nav = StateObject(
            wrappedValue: MoveToFolderNavigationContext(library: library)
        )
    }

    // MARK: - Строки

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

        guard let currentFolder = library.folder(for: currentId) else {
            return rows
        }

        let currentRow = MoveToFolderNavigationContext.FolderRow(
            id: currentId,
            name: currentFolder.name,
            hasSubfolders: currentFolder.subfolders.isEmpty == false
        )

        return [currentRow] + rows
    }

    // MARK: - Интерфейс

    var body: some View {
        List(orderedRows) { row in
            HStack(spacing: 12) {

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
                .accessibilityValue(
                    row.id == trackCurrentFolderId
                    ? MoveToFolderPresentationText.currentFolderAccessibilityValue
                    : ""
                )

                if row.id != trackCurrentFolderId {
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
                    .accessibilityLabel(
                        MoveToFolderPresentationText.selectFolderAccessibilityLabel(
                            for: row.name
                        )
                    )
                    .accessibilityValue(
                        selectedFolderId == row.id ? String(localized: "Selected") : ""
                    )
                } else {
                    Spacer()
                        .frame(width: 28)
                }
            }
            .overlay(alignment: .trailing) {

                if row.id == trackCurrentFolderId {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                        .frame(width: 28, height: 28)
                }
            }
            .listRowBackground(Color(.tertiarySystemBackground))
        }
        .navigationTitle(
            MoveToFolderPresentationText.navigationTitle(
                rootTitle: rootNavigationTitle,
                currentFolderName: nav.currentFolderName
            )
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
