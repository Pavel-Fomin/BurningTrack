//
//  NewTrackListSelectionState.swift
//  TrackList
//
//  Состояние sheet-flow выбора треков для создания или пополнения треклиста.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

struct NewTrackListSelectionState {
    /// Можно ли применить текущий выбор треков.
    var canSubmit: Bool
    /// Текст основной кнопки применения выбора.
    var buttonTitle: String
}
