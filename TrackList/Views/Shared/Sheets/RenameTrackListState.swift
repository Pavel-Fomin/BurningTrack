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
    var name: String
    /// Можно ли подтвердить переименование с текущим названием.
    var canSubmit: Bool
}
