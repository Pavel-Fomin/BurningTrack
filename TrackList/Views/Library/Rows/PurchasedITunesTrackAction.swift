//
//  PurchasedITunesTrackAction.swift
//  TrackList
//
//  Действия строки купленного iTunes-трека.
//
//  Created by Codex on 02.07.2026.
//

import Foundation

/// Пользовательские действия строки купленного iTunes-трека.
/// View отправляет только намерение, а выполнение остаётся в handler.
enum PurchasedITunesTrackAction {
    /// Пользователь запросил воспроизведение или паузу строки.
    case play(
        track: PurchasedITunesPlayableTrack,
        context: [PurchasedITunesPlayableTrack]
    )
    /// Пользователь запросил копирование через выбор папки назначения.
    case copy(track: PurchasedITunesPlayableTrack)
    /// Пользователь запросил карточку "О треке" для runtime iTunes-трека.
    case details(track: PurchasedITunesPlayableTrack)
    /// Пользователь запросил добавление iTunes-трека в треклист.
    case addToTrackList(track: PurchasedITunesPlayableTrack)
    /// Пользователь запросил добавление iTunes-трека в очередь плеера.
    case addToPlayer(track: PurchasedITunesPlayableTrack)
}
