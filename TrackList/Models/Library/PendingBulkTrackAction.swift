//
//  PendingBulkTrackAction.swift
//  TrackList
//
//  Зафиксированное массовое действие над выбранными треками.
//
//  Created by Pavel Fomin on 21.05.2026.
//

import Foundation

struct PendingBulkTrackAction {
    /// Действие, выбранное пользователем.
    let action: BulkTrackAction

    /// Идентификаторы треков в порядке выбора.
    let trackIDs: [UUID]

    /// Проверяет, есть ли выбранные треки для дальнейшего flow.
    var isEmpty: Bool {
        trackIDs.isEmpty
    }
}
