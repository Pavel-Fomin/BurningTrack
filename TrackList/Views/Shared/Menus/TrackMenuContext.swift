//
//  TrackMenuContext.swift
//  TrackList
//
//  Контекст, в котором отображается меню трека.
//
//  Created by Codex on 03.07.2026.
//

import Foundation

/// Раздел приложения, где пользователь открывает меню трека.
enum TrackMenuContext {
    /// Фонотека с локальными файлами приложения.
    case library
    /// Раздел купленных iTunes-треков.
    case purchasedITunes
    /// Очередь плеера.
    case player
    /// Detail-экран одного треклиста.
    case trackList
}
