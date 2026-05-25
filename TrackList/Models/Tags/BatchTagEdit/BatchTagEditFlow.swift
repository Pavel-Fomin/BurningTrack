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
    var artwork: BatchTagArtworkEditState       /// Состояние редактирования обложек.

    /// Активен ли flow массового редактирования тегов.
    var isActive: Bool {
        pendingAction != nil
    }
}
