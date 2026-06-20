//
//  RenameTrackListAction.swift
//  TrackList
//
//  Действия sheet-flow переименования треклиста.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

enum RenameTrackListAction {
    /// Пользователь изменил название треклиста.
    case nameChanged(String)
    /// Пользователь подтвердил переименование треклиста.
    case submit
    /// Пользователь закрыл sheet без переименования.
    case cancel
}
