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
    /// Сигнал на очистку текущего треклиста (вызывается, например, из меню чипса)
    static let clearTrackList = Notification.Name("clearTrackList")
    
    /// Сигнал, что треклист был переименован (используется для обновления UI)
    static let trackListDidRename = Notification.Name("trackListDidRename")
}
