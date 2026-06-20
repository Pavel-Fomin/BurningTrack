//
//  CreateTrackListAction.swift
//  TrackList
//
//  Действия sheet-flow создания треклиста.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

enum CreateTrackListAction {
    /// Пользователь изменил название треклиста.
    case nameChanged(String)
    /// Пользователь выбрал создание пустого треклиста.
    case createEmpty
    /// Пользователь выбрал добавление треков перед созданием.
    case addTracks
    /// Пользователь закрыл sheet без создания треклиста.
    case cancel
}
