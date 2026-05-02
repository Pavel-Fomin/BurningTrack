//
//  NotificationName.swift
//  TrackList
//
//  Расширение для объявления собственных Notification.Name
//  Используется для безопасной и централизованной работы с NotificationCenter
//
//  Created by Pavel Fomin on 23.05.2025.
//

import Foundation

extension Notification.Name {
    
    // MARK: - TrackList
    
    static let trackListsDidChange = Notification.Name("trackListsDidChange")       /// Любое изменение списка треклистов (создание/удаление/переименование)
    static let trackListTracksDidChange = Notification.Name("trackListTracksDidChange") /// Изменились треки внутри одного треклиста
    static let clearTrackList = Notification.Name("clearTrackList")                 /// Очистка текущего треклиста
    static let trackListDidRename = Notification.Name("trackListDidRename")         /// Треклист был переименован
    static let trackDidUpdate = Notification.Name("trackDidUpdate")                 /// Единое событие обновления трека с payload TrackUpdateEvent
    
    // MARK: - Library
    
    static let trackDidMove = Notification.Name("trackDidMove")                   /// Перемещение трека
    static let libraryAccessRestored = Notification.Name("libraryAccessRestored") /// Доступ к прикреплённым папкам восстановлен (root-scope открыт)
    
    // MARK: - Player
    
    static let trackDidFinish = Notification.Name("trackDidFinish")              /// Трек доиграл до конца (AVPlayerItem → PlayerManager → PlayerViewModel)
    static let trackDurationUpdated = Notification.Name("trackDurationUpdated")  /// Обновилась длительность текущего трека
}
