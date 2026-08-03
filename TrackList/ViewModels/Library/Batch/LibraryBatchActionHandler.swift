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
    let onAddToPlayer: @MainActor (PendingBulkTrackAction) -> Void
    let onAddToTrackList: @MainActor (PendingBulkTrackAction) -> Void
    let onRenameFiles: @MainActor (PendingBulkTrackAction) -> Void
    let onEditTags: @MainActor (PendingBulkTrackAction) -> Void

    /// Передаёт массовое действие в соответствующий сценарий и подтверждает его принятие.
    @discardableResult
    func handle(_ pendingAction: PendingBulkTrackAction) -> Bool {
        guard !pendingAction.isEmpty else { return false }

        switch pendingAction.action {
        case .addToPlayer:
            onAddToPlayer(pendingAction)
        case .addToTrackList:
            onAddToTrackList(pendingAction)
        case .renameFiles:
            onRenameFiles(pendingAction)
        case .editTags:
            onEditTags(pendingAction)
        }

        return true
    }
}
