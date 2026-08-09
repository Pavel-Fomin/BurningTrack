//
//  SaveTrackListState.swift
//  TrackList
//
//  Presentation-состояние sheet-flow сохранения очереди плеера в треклист.
//
//  Created by Pavel Fomin on 04.08.2026.
//

import Foundation

/// Готовое presentation-состояние формы сохранения очереди.
struct SaveTrackListState: Equatable {
    /// Текст, отображаемый в поле имени треклиста.
    let name: String
    /// Разрешено ли подтверждение с текущим именем и состоянием выполнения.
    let canSubmit: Bool
    /// Выполняется ли сохранение текущей очереди.
    let isSubmitting: Bool
}
