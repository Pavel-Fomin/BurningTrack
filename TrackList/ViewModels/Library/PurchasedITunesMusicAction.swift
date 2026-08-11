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
    /// Экран появился и должен загрузить системную медиатеку через handler.
    case appeared
    /// Пользователь выбрал другой порядок отображения треков.
    case sortModeSelected(PurchasedITunesTrackSortMode)
    /// Запускает экспорт всех треков в текущем отображаемом порядке ScreenState.
    case exportTracks
}
