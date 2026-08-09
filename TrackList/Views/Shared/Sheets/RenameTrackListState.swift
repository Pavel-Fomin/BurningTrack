//
//  RenameTrackListState.swift
//  TrackList
//
//  Состояние sheet-flow переименования треклиста.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

struct RenameTrackListState {
    /// Текущее название треклиста в форме.
    let name: String
    /// Можно ли подтвердить переименование с текущим названием.
    let canSubmit: Bool
    /// Выполняется ли доменная команда переименования.
    let isSubmitting: Bool
}
