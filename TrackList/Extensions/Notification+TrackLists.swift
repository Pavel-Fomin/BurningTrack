//
//  Notification+TrackLists.swift
//  TrackList
//
//  Расширение Notification.Name:
//  определяет системное уведомление о том, что состав треклистов изменился.
//  Используется для автоматического обновления фонотеки и UI
//
//  Created by Pavel Fomin on 07.11.2025.
//

import Foundation

extension Notification.Name {
    static let trackListsDidChange = Notification.Name("trackListsDidChange")
}
