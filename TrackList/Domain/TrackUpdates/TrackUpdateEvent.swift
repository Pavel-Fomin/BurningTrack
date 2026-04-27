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

    // MARK: - Identity

    let trackId: UUID                         /// Идентификатор трека

    // MARK: - Update info

    let reason: TrackUpdateReason             /// Причина обновления трека
    let changedFields: Set<TrackChangedField> /// Набор изменённых полей

    // MARK: - Snapshot

    let snapshot: TrackRuntimeSnapshot        /// Новый каноничный runtime snapshot трека
}
