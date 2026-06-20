//
//  LibraryBatchActionHandler.swift
//  TrackList
//
//  Маршрутизирует массовые действия фонотеки.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

/// Маршрутизирует массовые действия фонотеки.
/// Не хранит состояние selection и не выполняет сами batch-операции.
@MainActor
struct LibraryBatchActionHandler {
    let onRenameFiles: @MainActor (PendingBulkTrackAction) -> Void
    let onEditTags: @MainActor (PendingBulkTrackAction) -> Void

    /// Передаёт массовое действие в соответствующий сценарий.
    func handle(_ pendingAction: PendingBulkTrackAction) {
        guard !pendingAction.isEmpty else { return }

        switch pendingAction.action {
        case .renameFiles:
            onRenameFiles(pendingAction)
        case .editTags:
            onEditTags(pendingAction)
        case .addToPlayer, .addToTrackList:
            break
        }
    }
}
