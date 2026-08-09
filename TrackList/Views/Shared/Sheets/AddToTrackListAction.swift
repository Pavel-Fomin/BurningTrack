//
//  AddToTrackListAction.swift
//  TrackList
//
//  Действия feature-flow добавления треков в треклист.
//
//  Created by Pavel Fomin on 03.08.2026.
//

import Foundation

/// Typed-действия экрана выбора destination-треклиста.
enum AddToTrackListAction {
    /// Пользователь выбрал или снял выбор треклиста назначения.
    case trackListSelected(UUID)
    /// Пользователь подтвердил добавление треков.
    case submit
    /// Пользователь закрыл sheet без выполнения операции.
    case cancel
    /// SwiftUI подтвердил исчезновение конкретного sheet route.
    case sheetDisappeared
}
