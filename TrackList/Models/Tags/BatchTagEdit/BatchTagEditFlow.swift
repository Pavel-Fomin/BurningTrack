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
    var pendingAction: PendingBulkTrackAction?  /// Массовое действие, из которого была открыта форма.
    var phase: BatchTagEditPhase                /// Текущий этап формы.
    var tracks: [BatchTagEditTrack]             /// Треки, выбранные для массового редактирования.
    var fields: [BatchTagFieldEditState]        /// Состояния редактируемых текстовых полей.
    var trackFieldOverrides: [UUID: BatchTagTrackFieldOverride] /// Per-track изменения полей тегов.
    var artwork: BatchTagArtworkEditState       /// Состояние редактирования обложек.

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
