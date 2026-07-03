//
//  PlaybackContext.swift
//  TrackList
//
//  Created by Pavel Fomin on 07.08.2025.
//

import Foundation

enum PlaybackContext {
    /// Очередь основного плеера.
    case player
    /// Экран пользовательского треклиста.
    case trackList
    /// Обычная фонотека приложения.
    case library
    /// Раздел купленных треков iTunes.
    case purchasedITunes
    /// Неизвестный или одиночный контекст.
    case unknown
}

extension PlaybackContext {
    static func detect(from context: [any TrackDisplayable]) -> PlaybackContext {
        if context.first is PlayerTrack { return .player }
        if context.first is Track { return .trackList }
        if context.first is LibraryTrack { return .library }
        if context.first is PurchasedITunesPlayableTrack { return .purchasedITunes }
        return .unknown
    }
}
