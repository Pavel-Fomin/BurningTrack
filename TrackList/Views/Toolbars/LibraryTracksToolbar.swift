//
//  LibraryTracksToolbar.swift
//  TrackList
//
//  Тулбар экрана с треками в фонотеке.
//  Поддерживает режим мультиселекта.
//
//  Created by PavelFomin on 10.01.2026.
//

import SwiftUI

struct LibraryTracksToolbar: ViewModifier {

    let title: String
    let isSelecting: Bool
    let selectedCount: Int

    let onTapSelect: () -> Void
    let onSelectBatchAction: (BulkTrackAction) -> Void
    let onTapCancel: () -> Void
    
    // MARK: - UI
    
    func body(content: Content) -> some View {
        content
            .screenToolbar(
                title: isSelecting ? "Выбрано" : title,
                subtitle: isSelecting ? "\(selectedCount)" : nil,
                isTitleSecondary: isSelecting,
                leading: { leadingContent }
            )
            .toolbar {
                trailingToolbarContent
            }
    }

    // Контент слева не подменяет системную кнопку назад.
    @ViewBuilder
    private var leadingContent: some View {
        EmptyView()
    }

    // Контент справа отдаёт наружу только пользовательские намерения.
    @ToolbarContentBuilder
    private var trailingToolbarContent: some ToolbarContent {

        if isSelecting {

            // Меню batch-действий в режиме выбора.
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    batchActionMenuItems
                } label: {
                    Image(systemName: "ellipsis")
                }
            }

            /// Закрывает режим выбора и очищает текущий selection.
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onTapCancel) {
                    Image(systemName: "xmark")
                }
            }

        } else {

            /// Меню обычного режима.
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: onTapSelect) {
                        Label("Выбрать", systemImage: "checkmark.circle")
                    }

                    Divider()

                    batchActionMenuItems
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }

    /// Общие пункты batch-действий без выполнения самих действий.
    @ViewBuilder
    private var batchActionMenuItems: some View {
        // Системные секции меню выравнивают заголовки отдельно от пунктов с иконками.
        Section("Добавить") {
            Button {
                onSelectBatchAction(.addToPlayer)
            } label: {
                Label("В плеер", systemImage: "waveform")
            }

            Button {
                onSelectBatchAction(.addToTrackList)
            } label: {
                Label("В треклист", systemImage: "list.star")
            }
        }

        Section("Изменить") {
            Button {
                onSelectBatchAction(.renameFiles)
            } label: {
                Label("Переименовать файлы", systemImage: "pencil")
            }

            Button {
                onSelectBatchAction(.editTags)
            } label: {
                Label("Редактировать теги", systemImage: "tag")
            }
        }
    }
}

// MARK: - Modifier

extension View {

    func libraryTracksToolbar(
        title: String,
        isSelecting: Bool,
        selectedCount: Int,
        onTapSelect: @escaping () -> Void,
        onSelectBatchAction: @escaping (BulkTrackAction) -> Void,
        onTapCancel: @escaping () -> Void
    ) -> some View {
        self.modifier(
            LibraryTracksToolbar(
                title: title,
                isSelecting: isSelecting,
                selectedCount: selectedCount,
                onTapSelect: onTapSelect,
                onSelectBatchAction: onSelectBatchAction,
                onTapCancel: onTapCancel,
            )
        )
    }
}
