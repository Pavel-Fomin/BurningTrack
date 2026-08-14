//
//  BatchTagEditFlow.swift
//  TrackList
//
//  Состояние flow массового редактирования тегов.
//
//  Created by Pavel Fomin on 25.05.2026.
//

import Foundation

struct BatchTagEditFlow {
    var pendingAction: PendingBulkTrackAction?
    var phase: BatchTagEditPhase
    var tracks: [BatchTagEditTrack]
    var fields: [BatchTagFieldEditState]
    /// Переопределения полей, относящиеся к конкретным трекам, а не ко всей выборке.
    var trackFieldOverrides: [UUID: BatchTagTrackFieldOverride]
    var artwork: BatchTagArtworkEditState

    /// Активен ли flow массового редактирования тегов.
    var isActive: Bool {
        pendingAction != nil
    }

    /// Можно ли сохранить изменения.
    var canSave: Bool {
        guard phase == .editing else { return false }
        guard !tracks.isEmpty else { return false }
        guard !artwork.isCompressing else { return false }
        guard !artwork.isPreparing else { return false }
        let hasFieldChanges = fields.contains { field in
            field.action != .keep
        }
        let hasTrackFieldOverrides = trackFieldOverrides.values.contains { override in
            override.fields.values.contains { field in
                field.action != .keep
            }
        }
        let hasArtworkChanges = artwork.hasChanges
        return hasFieldChanges || hasTrackFieldOverrides || hasArtworkChanges
    }
}
