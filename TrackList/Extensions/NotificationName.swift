//
//  Notification+Name.swift
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
    
    static let trackListsDidChange = Notification.Name("trackListsDidChange")   /// Любое изменение списка треклистов (создание/удаление/переименование)
    static let clearTrackList = Notification.Name("clearTrackList")             /// Очистка текущего треклиста
    static let trackListDidRename = Notification.Name("trackListDidRename")     /// Треклист был переименован
    
    // MARK: - Library
    
    static let trackDidMove = Notification.Name("trackDidMove")                 /// Перемещение трека
   
    // MARK: - Player
    
    static let trackDidFinish = Notification.Name("trackDidFinish")              /// Трек доиграл до конца (AVPlayerItem → PlayerManager → PlayerViewModel)
    static let trackDurationUpdated = Notification.Name("trackDurationUpdated")  /// Обновилась длительность текущего трека
}


