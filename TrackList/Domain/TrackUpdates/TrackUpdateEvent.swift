//
//  TrackUpdateEvent.swift
//  TrackList
//
//  Единое событие обновления трека.
//  Используется как главный payload нового контракта обновления:
//  - сообщает, какой трек обновился
//  - сообщает, почему произошло обновление
//  - сообщает, какие поля изменились
//  - несёт новый каноничный runtime snapshot
//
//  Created by PavelFomin on 24.04.2026.
//

import Foundation

/// Единое событие обновления трека.
///
/// Используется как главный payload нового контракта обновления:
/// - сообщает, какой трек обновился
/// - сообщает, почему произошло обновление
/// - сообщает, какие поля изменились
/// - несёт новый каноничный runtime snapshot
struct TrackUpdateEvent: Equatable {

    // MARK: - Идентичность

    let trackId: UUID

    // MARK: - Сведения об обновлении

    let reason: TrackUpdateReason
    let changedFields: Set<TrackChangedField>

    // MARK: - Снимок

    let snapshot: TrackRuntimeSnapshot
}
