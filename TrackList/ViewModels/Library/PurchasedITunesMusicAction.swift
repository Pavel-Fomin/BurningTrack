//
//  PurchasedITunesMusicAction.swift
//  TrackList
//
//  Действия экрана «Куплено в iTunes».
//
//  Created by Pavel Fomin on 23.07.2026.
//

import Foundation

/// Описывает пользовательские намерения уровня всего раздела iTunes.
enum PurchasedITunesMusicAction {
    /// Запускает экспорт всех доступных треков в текущем отображаемом порядке.
    case exportTracks([PurchasedITunesPlayableTrack])
}
