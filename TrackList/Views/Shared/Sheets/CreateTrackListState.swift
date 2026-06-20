//
//  CreateTrackListState.swift
//  TrackList
//
//  Состояние sheet-flow создания треклиста.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

struct CreateTrackListState {
    /// Текущее название нового треклиста.
    var name: String
    /// Можно ли выполнить действие с текущим названием.
    var canSubmit: Bool
}
