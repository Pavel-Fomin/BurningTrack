//
//  NewTrackListSelectionAction.swift
//  TrackList
//
//  Действия sheet-flow выбора треков для создания или пополнения треклиста.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

enum NewTrackListSelectionAction {
    /// Пользователь подтвердил выбранные треки.
    case submit
    /// Пользователь закрыл sheet без применения выбора.
    case cancel
}
