//
//  TrackListsAction.swift
//  TrackList
//
//  Действия экрана списка треклистов.
//
//  Created by Pavel Fomin on 15.06.2026.
//

import Foundation

enum TrackListsAction {
    /// Экран появился.
    case onAppear
    /// Пользователь запросил создание нового треклиста.
    case createTrackList
    /// Пользователь запросил удаление треклиста.
    case requestDeleteTrackList(UUID)
    /// Пользователь подтвердил удаление треклиста.
    case confirmDeleteTrackList(UUID)
    /// Пользователь отменил удаление треклиста.
    case cancelDeleteTrackList
}
