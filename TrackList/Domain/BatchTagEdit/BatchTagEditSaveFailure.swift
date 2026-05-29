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
struct BatchTagEditSaveFailure: Identifiable {
    /// Идентификатор трека.
    let trackId: UUID
    /// Ошибка, полученная при сохранении.
    let error: Error
    /// Идентификатор для SwiftUI-списков.
    var id: UUID {
        trackId
    }
}
