//
//  RenameTrackFileAction.swift
//  TrackList
//
//  Typed-действия sheet-flow ручного переименования файла трека.
//
//  Created by Pavel Fomin on 08.08.2026.
//

import Foundation

enum RenameTrackFileAction {
    /// Пользователь изменил имя файла в форме.
    case fileNameChanged(String)
    /// Пользователь подтвердил ручное переименование.
    case rename
    /// Пользователь закрыл sheet без выполнения операции.
    case close
    /// Пользователь разрешил остановить воспроизведение и повторить операцию.
    case confirmStopPlayback
    /// Пользователь закрыл системный alert.
    case dismissAlert
    /// SwiftUI подтвердил исчезновение конкретного sheet route.
    case sheetDisappeared
}
