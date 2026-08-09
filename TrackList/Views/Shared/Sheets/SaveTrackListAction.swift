//
//  SaveTrackListAction.swift
//  TrackList
//
//  Typed-действия sheet-flow сохранения очереди плеера в треклист.
//
//  Created by Pavel Fomin on 04.08.2026.
//

import Foundation

/// Описывает действия, которые UI формы передаёт во ViewModel.
enum SaveTrackListAction {
    /// Пользователь изменил название нового треклиста.
    case nameChanged(String)
    /// Пользователь подтвердил сохранение текущей очереди.
    case submit
    /// Пользователь закрыл sheet без сохранения.
    case cancel
    /// SwiftUI подтвердил исчезновение конкретного sheet route.
    case sheetDisappeared
}
