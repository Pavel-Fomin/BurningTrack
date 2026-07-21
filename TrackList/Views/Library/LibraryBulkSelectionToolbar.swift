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
                areAllVisibleTracksSelected ? "Deselect All" : "Select All",
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
        Section("Add") {
            Button {
                onBatchActionSelection(.addToPlayer)
            } label: {
                Label("Add to Player", systemImage: "waveform")
            }

            Button {
                onBatchActionSelection(.addToTrackList)
            } label: {
                Label("Add to Tracklist", systemImage: "list.star")
            }
        }

        Section("Edit") {
            Button {
                onBatchActionSelection(.renameFiles)
            } label: {
                Label("File Name", systemImage: "pencil")
            }

            Button {
                onBatchActionSelection(.editTags)
            } label: {
                Label("Tags", systemImage: "tag")
            }
        }
    }
}
