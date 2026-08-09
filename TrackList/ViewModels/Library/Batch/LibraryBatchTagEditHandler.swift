//
//  LibraryBatchTagEditHandler.swift
//  TrackList
//
//  Маршрутизирует массовое редактирование тегов фонотеки в feature-local sheet.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Тонкий адаптер Library Tracks без metadata, сохранения и Toast-логики Batch Tag Edit.
@MainActor
final class LibraryBatchTagEditHandler {
    /// Открывает immutable route через общий lifecycle sheet-ов.
    private let router: any BatchTagEditRouting

    init(router: any BatchTagEditRouting) {
        self.router = router
    }

    /// Передаёт зафиксированное пользовательское намерение в feature-local flow.
    func startEdit(with pendingAction: PendingBulkTrackAction) {
        router.presentBatchTagEdit(pendingAction: pendingAction)
    }
}
