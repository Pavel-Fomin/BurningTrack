//
//  LibraryBulkSelectionToolbar.swift
//  TrackList
//
//  Общая панель навигации режима массового выбора треков фонотеки.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import SwiftUI

/// Общая панель навигации для массового выбора треков на экранах фонотеки.
struct LibraryBulkSelectionToolbar: ToolbarContent {
    /// Показывает, выбраны ли все треки текущего видимого списка.
    let areAllVisibleTracksSelected: Bool
    /// Передаёт массовое переключение выбора владельцу экрана.
    let onToggleSelectAll: () -> Void
    /// Передаёт выбор массового действия владельцу экрана.
    let onBatchActionSelection: (BulkTrackAction) -> Void
    /// Передаёт отмену режима выбора владельцу экрана.
    let onCancel: () -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        // Кнопка заменяет системный возврат только в активном режиме выбора.
        ToolbarItem(placement: .topBarLeading) {
            Button(
                areAllVisibleTracksSelected ? "Снять все" : "Выбрать все",
                action: onToggleSelectAll
            )
        }

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
            Button(action: onCancel) {
                Image(systemName: "xmark")
            }
        }
    }

    /// Общие пункты batch-действий без выполнения самих действий.
    @ViewBuilder
    private var batchActionMenuItems: some View {
        // Системные секции меню выравнивают заголовки отдельно от пунктов с иконками.
        Section("Добавить") {
            Button {
                onBatchActionSelection(.addToPlayer)
            } label: {
                Label("В плеер", systemImage: "waveform")
            }

            Button {
                onBatchActionSelection(.addToTrackList)
            } label: {
                Label("В треклист", systemImage: "list.star")
            }
        }

        Section("Изменить") {
            Button {
                onBatchActionSelection(.renameFiles)
            } label: {
                Label("Имя файла", systemImage: "pencil")
            }

            Button {
                onBatchActionSelection(.editTags)
            } label: {
                Label("Теги", systemImage: "tag")
            }
        }
    }
}
