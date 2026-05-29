//
//  BatchTagTrackFieldOverride.swift
//  TrackList
//
//  Изменения полей тегов для одного трека внутри batch-редактирования.
//
//  Created by Pavel Fomin on 28.05.2026.
//

import Foundation

/// Изменения полей тегов для одного трека внутри batch-редактирования.
///
/// Роль:
/// - хранит только per-track изменения;
/// - не содержит untouched поля;
/// - используется, когда пользователь редактирует поле при выбранной карточке конкретного трека.
struct BatchTagTrackFieldOverride: Identifiable, Equatable {
    /// Идентификатор трека.
    let trackId: UUID
    /// Изменённые поля конкретного трека.
    var fields: [EditableTrackField: BatchTagFieldEditState]
    /// Идентификатор для SwiftUI-списков.
    var id: UUID {
        trackId
    }
}
