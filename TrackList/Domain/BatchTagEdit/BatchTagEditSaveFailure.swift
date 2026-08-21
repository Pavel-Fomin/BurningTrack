//
//  BatchTagEditSaveFailure.swift
//  TrackList
//
//  Ошибка сохранения тегов одного трека в batch-операции.
//
//  Created by Pavel Fomin on 27.05.2026.
//

import Foundation

/// Ошибка сохранения тегов одного трека в batch-операции.
struct BatchTagEditSaveFailure: Identifiable, Sendable {
    /// Идентификатор трека.
    let trackId: UUID
    /// Семантика уже выполненной mutation и её recovery без потери состояния до presentation-слоя.
    let failure: MutationFailure
    /// Идентификатор для SwiftUI-списков.
    var id: UUID {
        trackId
    }
}
