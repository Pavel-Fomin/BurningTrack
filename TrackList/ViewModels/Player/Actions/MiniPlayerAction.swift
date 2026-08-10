//
//  MiniPlayerAction.swift
//  TrackList
//
//  Пользовательские действия мини-плеера.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import Foundation

/// Пользовательские намерения, доступные из мини-плеера.
enum MiniPlayerAction {
    /// Переключает воспроизведение и паузу текущего трека.
    case playPause
    /// Запрашивает переход к предыдущему треку текущего контекста.
    case playPrevious
    /// Запрашивает переход к следующему треку текущего контекста.
    case playNext
    /// Запрашивает перемотку к указанному времени текущего трека.
    case seek(TimeInterval)
    /// Переключает подтверждённое состояние текущего трека в «Избранном».
    case toggleFavorite
    /// Переключает режим случайного воспроизведения.
    case toggleShuffle
    /// Переключает режим повтора всего контекста.
    case toggleRepeatAll
    /// Переключает режим повтора текущего трека.
    case toggleRepeatOne
    /// Показывает текущий трек в фонотеке.
    case showCurrentTrackInLibrary
    /// Сохраняет новое локальное состояние раскрытия мини-плеера.
    case setExpanded(Bool)
}
