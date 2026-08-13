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
    /// Пользователь изменил выбор одного трека.
    case toggleTrack(LibraryTrack)
    /// Пользователь нажал недоступную строку без изменения selection.
    case unavailableTrackTapped(LibraryTrack)
    /// Пользователь выбрал все треки открытой папки.
    case selectAll([LibraryTrack])
    /// Пользователь снял выбор со всех треков открытой папки.
    case deselectAll([LibraryTrack])
    /// Пользователь подтвердил выбранные треки.
    case submit
    /// Пользователь закрыл sheet без применения выбора.
    case cancel
    /// SwiftUI подтвердил исчезновение конкретного sheet route.
    case sheetDisappeared
}
